import time
from collections import defaultdict
from typing import Dict, List, Tuple
from fastapi import Request, Response, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    In-memory sliding window rate limiter to protect QuietPath endpoints
    against denial-of-service (DoS), scraping, and automated tampering.
    """

    def __init__(
        self,
        app,
        max_requests_per_minute: int = 120,
        burst_limit_5s: int = 35,
    ):
        super().__init__(app)
        self.max_rpm = max_requests_per_minute
        self.burst_limit = burst_limit_5s
        # client_ip -> list of timestamps
        self.history: Dict[str, List[float]] = defaultdict(list)
        self.last_cleanup = time.time()

    def _cleanup_old_entries(self, now: float):
        """Purge entries older than 60 seconds every 30 seconds."""
        if now - self.last_cleanup < 30:
            return
        self.last_cleanup = now
        stale_cutoff = now - 60.0
        keys_to_delete = []
        for ip, timestamps in self.history.items():
            self.history[ip] = [t for t in timestamps if t > stale_cutoff]
            if not self.history[ip]:
                keys_to_delete.append(ip)
        for k in keys_to_delete:
            del self.history[k]

    async def dispatch(self, request: Request, call_next) -> Response:
        # Exclude documentation and health check from aggressive rate limiting
        path = request.url.path
        if path in ("/docs", "/redoc", "/openapi.json", "/api/v1/health"):
            return await call_next(request)

        # Resolve client IP (supporting X-Forwarded-For if behind proxy)
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            client_ip = forwarded.split(",")[0].strip()
        else:
            client_ip = request.client.host if request.client else "unknown"

        now = time.time()
        self._cleanup_old_entries(now)

        # Sliding window filter (last 60s and last 5s)
        window_60s = now - 60.0
        window_5s = now - 5.0

        records = [t for t in self.history[client_ip] if t > window_60s]
        burst_records = [t for t in records if t > window_5s]

        if len(records) >= self.max_rpm or len(burst_records) >= self.burst_limit:
            retry_after = 60 - int(now - records[0]) if records else 10
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={
                    "detail": "Rate limit exceeded. Please slow down your requests to preserve calm server telemetry.",
                    "retry_after_seconds": max(1, retry_after),
                },
                headers={"Retry-After": str(max(1, retry_after))},
            )

        records.append(now)
        self.history[client_ip] = records

        response = await call_next(request)
        return response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Applies defensive HTTP security headers to protect against clickjacking,
    MIME confusion, cross-site scripting (XSS), and referer leakage.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(self), microphone=(self)"
        return response
