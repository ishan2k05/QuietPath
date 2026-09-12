from fastapi import APIRouter
from app.schemas.route import RouteEvaluateRequest, RouteEvaluationResponse
from app.services.route_service import RouteService

router = APIRouter()


@router.post("/evaluate", response_model=RouteEvaluationResponse, tags=["Routing & Scoring"])
async def evaluate_routes(request: RouteEvaluateRequest):
    """
    Evaluates candidate routes against user's sensory profile using
    deterministic multi-criteria scoring and live environmental data.
    """
    return await RouteService.evaluate_routes(
        origin=request.origin,
        destination=request.destination,
        profile=request.profile,
        origin_lat=request.origin_lat,
        origin_lng=request.origin_lng,
        dest_lat=request.dest_lat,
        dest_lng=request.dest_lng,
    )
