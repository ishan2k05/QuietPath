# QuietPath — Phased Procedure Plan
**Project:** Sensory-Friendly Navigation Application  
**Target:** Final Year Project (FYP) & Production Prototype  
**Date:** September 2026  
**Document Location:** `docs/procedure_plan.md`

---

## Executive Summary & Architecture Overview

QuietPath enhances standard navigation by evaluating environmental stimuli (noise, crowds, traffic, construction, air quality, lighting) against a user's personalized sensory profile.

- **Frontend:** Flutter (Dart) — `Riverpod`, `GoRouter`, `Dio`, `Flutter TTS`, Custom Impeller Canvas Painter, `LocationService`, `OfflineCacheService`.
- **Backend:** FastAPI (Python 3.11/3.14) — `Pydantic`, `SQLAlchemy`, `NumPy`, `Pandas`, `HTTPX`, `Uvicorn`.
- **Spatial Database:** SQLite (dev/embedded) / PostgreSQL with PostGIS (prod container).
- **Routing & Maps:** Deterministic Multi-Criteria Decision Analysis (MCDA) routing engine with custom vector sensory canvas and Open-Meteo live AQI telemetry.
- **Algorithm:** 100% deterministic, explainable mathematical scoring engine (Multi-Criteria Decision Analysis — strictly **no LLM**).

---

## Master Phase Roadmap

```
Phase 1: Backend Foundation & API Health Check (Completed)
   ↓
Phase 2: Database Layer & Spatial Seeding (Completed)
   ↓
Phase 3: User Management & Sensory Profile Engine (Completed)
   ↓
Phase 4: Deterministic Sensory Scoring Algorithm (Completed)
   ↓
Phase 5: Environmental Data Ingestion & Live Open-Meteo AQI (Completed)
   ↓
Phase 6: Multi-Criteria Route Evaluation API (Completed)
   ↓
Phase 7: Sensory-Friendly Safe Space MCDA Recommendation Service (Completed)
   ↓
Phase 8: Flutter Mobile App — Sensory Theme & Dynamic Networking (Completed)
   ↓
Phase 9: Flutter Mobile App — Dual-Mode Sensory Profile & Settings UI (Completed)
   ↓
Phase 10: Flutter Mobile App — Interactive Map Canvas & Route Comparison (Completed)
   ↓
Phase 11: Flutter Mobile App — Turn-by-Turn Simulation Engine & Voice Guidance (Completed)
   ↓
Phase 12: End-to-End Integration, Validation & Academic Deliverables (Completed)
   ↓
Phase 13: Production Deployment Readiness & Hardware Packaging (Completed)
   ↓
Phase 14: Real-Time Hazards Database & Dynamic Avoidance (Completed)
   ↓
Phase 15: Map Interaction & Sensory UI Decluttering (Completed)
   ↓
Phase 16: Hardware GPS, Live Tile Layers & Release Deployment (Up Next)
```

---

## Phase 1: Backend Foundation & API Health Check
- [x] **1.1 Directory Scaffolding**: Modular enterprise architecture in `backend/app/`.
- [x] **1.2 Settings & Environment Configuration**: `config.py` with environment variable loading for CORS, SQLite/PostgreSQL URLs, and security keys.
- [x] **1.3 FastAPI Application Factory**: `main.py` with `/api/v1/health` endpoint and automatic database initialization.
- [x] **1.4 Dependency Verification**: Verified `requirements.txt` with FastAPI, Uvicorn, NumPy, Pandas, SQLAlchemy, HTTPX.
- [x] **1.5 Local Server Execution**: Uvicorn daemon running on port 8000 with auto-reload.

---

## Phase 2: Database Layer & Spatial Seeding
- [x] **2.1 Database Connection & Scoping**: `get_db()` session dependency in `core/database.py`.
- [x] **2.2 Safe Spaces Catalog Seeding**: Seeded Bangalore sensory retreats (Central Public Library, Botanical Gardens Conservatory, Mute Coffee Shop, Cubbon Park Bamboo Grove, NGMA, Atta Galatta, Sankey Tank Promenade).
- [x] **2.3 User & Profile ORM Models**: `User` and `SensoryProfileModel` tables.

---

## Phase 3: User Management & Sensory Profile Engine
- [x] **3.1 Profile Schemas & Models**: `SensoryProfileCreate`, `SensoryProfileResponse`, and `SensoryProfileUpdate`.
- [x] **3.2 Mathematical Weight Normalization**: Normalization to unity ($\sum w_i = 1.0$) based on user tolerance inputs.
- [x] **3.3 Profile Endpoints**: `POST /api/v1/profiles/` and `GET /api/v1/profiles/{user_id}`.
- [x] **3.4 Unit Tests**: Verified in `tests/test_database.py`.

---

## Phase 4: Deterministic Sensory Scoring Algorithm (Core Engine)
- [x] **4.1 Mathematical Formulation**: Implemented in `algorithms/sensory_scorer.py` using pure NumPy (0% LLM).
- [x] **4.2 Multi-Factor Penalty Normalization**: Equations for noise ($dB$), crowd density, traffic congestion, and construction proximity.
- [x] **4.3 Calibrated Sensory Score Derivation**: Exponential mapping yielding calibrated 0-100 scores.
- [x] **4.4 Unit Tests**: Comprehensive test suite verified in `tests/test_sensory_scorer.py`.

---

## Phase 5: Environmental Data Ingestion & Live Open-Meteo AQI
- [x] **5.1 Real-Time Open-Meteo Integration**: Asynchronous European Air Quality API client for European/US AQI and PM2.5/PM10 readings.
- [x] **5.2 Construction Hazard Zone Modeling**: Gaussian radial distance penalty field.
- [x] **5.3 Resilient Fallback Architecture**: Graceful fallback to historical baseline telemetry during network outages.

---

## Phase 6: Multi-Criteria Route Evaluation API
- [x] **6.1 Route Evaluation Endpoint**: `POST /api/v1/routes/evaluate`.
- [x] **6.2 Side-by-Side Comparison**: Returns Calmest Route (low sensory load, high comfort score) vs Quickest Route (urban arterial road).
- [x] **6.3 Detailed Factor Breakdown**: Return percentage contributions for Noise, Crowd, Traffic, Construction, Light, and AQI.

---

## Phase 7: Sensory-Friendly Safe Space MCDA Recommendation Service
- [x] **7.1 Safe Spaces Catalog Endpoint**: `GET /api/v1/places/safe-spaces` with category filtering.
- [x] **7.2 Tailored Recommendation Endpoint**: `GET /api/v1/places/recommended` accepting user sensory profile parameters and computing personalized match scores ($60\% - 98\%$).
- [x] **7.3 Haversine Geographic Distance**: On-the-fly local spatial calculations.

---

## Phase 8: Flutter Mobile App — Sensory Theme & Dynamic Networking
- [x] **8.1 Sensory Design System**: Sage (`#8BB174`), Eucalyptus (`#6A9C89`), Lavender (`#B5A8D5`), Soft Cream (`#EFF2EE`), and Charcoal typography.
- [x] **8.2 Dynamic ApiClient**: Network client with automatic emulator loopback (`10.0.2.2`), localhost fallback, and `--dart-define=API_BASE_URL` support.
- [x] **8.3 Smooth Sensory Tab Transitions**: `AnimatedSwitcher` combining `FadeTransition` and 1.5% `SlideTransition` with `Curves.easeOutCubic` (280ms duration) preventing visual disorientation.

---

## Phase 9: Flutter Mobile App — Dual-Mode Sensory Profile UI
- [x] **9.1 Mode 1 (Onboarding Flow)**: 3-track initial calibration (*Noise*, *Crowd*, *Light*) with welcoming leaf badge.
- [x] **9.2 Mode 2 (In-App Settings Flow)**: Full 5-track sensitivity customization (*Noise*, *Crowd*, *Light*, *Traffic*, *Detour Willingness*) with live Riverpod state sync and confirmation SnackBar.

---

## Phase 10: Flutter Mobile App — Interactive Map Canvas & Route Comparison
- [x] **10.1 Dynamic Vector Canvas (`SensoryMapCanvas`)**: CustomPainter dynamically drawing start, destination pins, and calm vs fast route Bezier curves.
- [x] **10.2 Destination Selection Sheet**: Search sheet for Bangalore landmarks (*Bangalore Golf Club*, *Cubbon Park Sanctuary*, *Lalbagh*, *Central Public Library*, *Commercial Street*).
- [x] **10.3 Route Comparison Overlay**: Side-by-side cards with score badges, time delta, and tactile badges.
- [x] **10.4 MCDA Explainability Modal**: Tap-to-inspect factor breakdown showing exact penalty percentages.

---

## Phase 11: Flutter Mobile App — Turn-by-Turn Navigation & Guidance
- [x] **11.1 Simulation Stepper Engine**: `< Step 1 of 4 >` interactive controls advancing through maneuvers with arrival state.
- [x] **11.2 Live Decibel Metric**: Dynamic ambient noise reading (`38 dB` - `45 dB`) on the HUD.
- [x] **11.3 Calm Voice Guidance (`TtsService`)**: Cadence settings (*Gentle 0.38x*, *Calm 0.45x*, *Normal 0.55x*) and interactive speech cue previews.
- [x] **11.4 Emergency Guided Exit**: One-tap panic exit navigation from any safe sanctuary card directly into turn-by-turn guidance.

---

## Phase 12: End-to-End Integration, Validation & FYP Deliverables
- [x] **12.1 Live Emulator Verification**: Fully verified on Pixel 8 Android emulator (`emulator-5554`).
- [x] **12.2 Academic FYP Mathematical Defense Document**: Created `docs/algorithm_math_defense.md` compiling MCDA cost equations, normalization proofs, and viva defense Q&A.
- [x] **12.3 Automated Test Suite**: 100% passing tests across Python backend (`test_api.py`, `test_sensory_scorer.py`, `test_database.py`) and Flutter (`flutter test`, `flutter analyze lib/`).

---

## Phase 13: Production Deployment Readiness & Hardware Packaging
- [x] **13.1 Production Dockerfile**: Created `backend/Dockerfile` with Python 3.11 slim, multi-stage build, non-root user, and health check.
- [x] **13.2 Docker Compose Configuration**: Created `backend/docker-compose.yml` for unified 1-click cloud deployment.
- [x] **13.3 Production Android Permissions**: Configured `INTERNET`, `ACCESS_FINE_LOCATION`, and `ACCESS_COARSE_LOCATION` in `AndroidManifest.xml`.
- [x] **13.4 App Branding**: Renamed app label to `QuietPath` for release builds.
- [x] **13.5 Location Service**: Implemented `LocationService` with Haversine distance and coordinate management.
- [x] **13.6 Resilient Offline Cache Service**: Implemented `OfflineCacheService` for network-resilient offline navigation.

---

## Phase 14: Real-Time Sensory Hazards Database & Dynamic Crowdsourced Avoidance
- [x] **14.1 Persistent Hazards Database Model**: Implemented `HazardModel` in `backend/app/models/hazard.py` with auto-expiry, severity 1-5, coordinates, and community upvotes.
- [x] **14.2 REST Hazard Endpoints**: Implemented `POST /api/v1/hazards/`, `GET /api/v1/hazards/active` (radius-based spatial filtering), and `POST /api/v1/hazards/{id}/upvote`.
- [x] **14.3 Dynamic Route Sensory Penalization**: Integrated active unexpired database hazard penalties dynamically into `backend/app/services/route_service.py`.
- [x] **14.4 OpenStreetMap Live Geocoding**: Integrated asynchronous Nominatim geocoding fallback in `geocoding_service.py` for arbitrary address lookups.
- [x] **14.5 Mobile Hazards State (`hazardsProvider`)**: Riverpod state notifier managing active hazards, optimistic updates, and community upvoting.
- [x] **14.6 Mobile Reporting Modal & Live Canvas Markers**: Bottom sheet UI (`_openReportHazardSheet`) allowing users to report stimulus spikes and visualizing active hazards directly on `SensoryMapCanvas`.

---

## Phase 15: Map Interaction & Sensory UI Decluttering (Completed)
- [x] **15.1 Interactive Gesture Engine**: Integrated `InteractiveViewer` with `TransformationController` supporting smooth one-finger pan and two-finger pinch-to-zoom ($0.75\times$ to $3.5\times$).
- [x] **15.2 Floating Map Action Controls**: Added floating quick-actions: 🎯 Recenter, ➕ Zoom In, ➖ Zoom Out, and 🌲 Sensory Canopy Shading Toggle.
- [x] **15.3 Collapsible Peek Bottom Sheet**: Minimalist $\sim 115\text{px}$ peek sheet preserving $>75\%$ of screen for the map, expandable to full side-by-side route comparison.
- [x] **15.4 Interactive Hazard Pin Callouts**: Tapping any hazard pin displays an on-pin callout and floating dismissible incident detail capsule.
- [x] **15.5 Safe Spaces Visual Cleanup**: Reduced card visual density by 50% with consolidated match badges, max 2 tags, and clean 4px capacity bar.
- [x] **15.6 Dynamic Navigation GPS Progression**: User location beacon interpolates along route curve dynamically as maneuvers advance.
- [x] **15.7 Non-Technical Profile Copy**: Eliminated developer MCDA jargon for comforting, user-focused language.

---

## Phase 16: Real-Time Map & Tile Layer Integration (Completed)
- [x] **16.1 Slippy Tile / Real-Time Raster Street Map Integration**: Implemented `SensoryTileLayer` with high-performance Web Mercator ($256\times 256$) slippy tile engine rendering real-time street cartography (ArcGIS World Street Map & OpenStreetMap) underneath the sensory map canvas with zero native dependencies.
- [x] **16.2 Real-Time Street Map Toggle Controls**: Added floating 🗺️ `Layers` quick-action button allowing instant toggle between High-Resolution Real Street Map and Pure Low-Stimulus Sensory Vector Canvas.
- [x] **16.3 Active Navigation Street Tile Integration**: Stacked real-time street tiles behind turn-by-turn maneuvers in `ActiveNavigationScreen` with dynamic GPS beacon tracking.
- [x] **16.4 Global Button Descender & Padding Fix**: Fixed font descender clipping (`'y'` in *"Sanctuary"* and `'g'` in *"Exploring"*) across `SafeSpacesScreen`, `ExploreMapScreen`, `ActiveNavigationScreen`, and `SensoryProfileSetupScreen` with proper vertical padding, `Alignment.center`, line-height `1.2`, and 110dp list bottom clearance above navigation bar.

---

## Phase 17: Local Configuration Storage & Real-Time Navigation Integration (Completed)
- [x] **17.1 Persistent Local Configuration (`AppConfigService`)**: Implemented zero-dependency singleton storage service serializing user settings, sensory profile weights, onboarding status, tile toggles, voice preferences, and last known GPS coordinates directly to `quietpath_config.json`.
- [x] **17.2 First-Launch Gating & Onboarding Completion**: First-time onboarding screen (`SensoryProfileSetupScreen`) displays all 5 sensory preference categories (Noise, Crowd, Light, Traffic Congestion, Detour Willingness), sets `hasCompletedOnboarding = true` on save, and bypasses onboarding on all subsequent launches.
- [x] **17.3 Animated Brand Splash Screen (`SplashScreen`)**: Added calming launch screen with scaled and faded leaf logo, "QuietPath" branding, and "Navigate at your own pace" tagline that smoothly routes based on local configuration.
- [x] **17.4 Real-Time Map & GPS Navigation Linking**: Connected `userLocationProvider` to `SensoryTileLayer` and `SensoryMapCanvas`. Slippy tile layers dynamically re-anchor to real-time coordinates, and turn-by-turn navigation advances the user beacon along actual Bangalore streets.
- [x] **17.5 Settings Synchronization Across App**: Config changes in map layer toggles, voice guidance switches, and profile setup persist instantly to local storage.
- [x] **17.6 Frosted Translucent Top Header Bar with Soft Grey Border**: Implemented `BackdropFilter` (blur 12px) container with frosted background (`#EFF2EE`, 92% opacity) and soft grey bottom separator border (`#CBD6CA`) over the map canvas. Completely shields the "QuietPath" brand and icons from intersecting street lines or text labels.
- [x] **17.7 Safe Spaces Tab UI Decluttering**: Completely decluttered venue cards by removing redundant capacity progress bars, percentage strings, and verbose refuge notes. Streamlined cards into an elegant 3-row layout with venue name, match score pill, single highlight tag, and a compact 34px right-aligned action button. Enabled full-card tap-to-navigate.

---

## Phase 18: Real-Time Hardware GPS, World Map & External Sensory Telemetry (Completed)
- [x] **18.1 Real-Time Hardware GPS & Location Services (Completed)**: Integrated `geolocator: ^14.0.3`, configured runtime Android permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`), implemented streaming in `LocationService` with 3-meter distance filter, dynamic accuracy halo in `SensoryMapCanvas`, and graceful fallback to simulated coordinates.
- [x] **18.2 Google Maps Platform & World Cartography (Completed)**: Integrated `google_maps_flutter: ^2.18.0` with Android API key meta-data, custom low-contrast sensory JSON styling (`sensory_map_styles.dart` with desaturated highways, eucalyptus green spaces, soft water, and suppressed commercial POIs), and multi-mode map view switching (`googleMaps` vector $\leftrightarrow$ `streetTiles` raster $\leftrightarrow$ `pureCanvas` vector canvas) backed by disk persistence in `AppConfigService`.
- [x] **18.3 Live Environmental Telemetry (AQI & Weather APIs) (Completed)**: Implemented `environmental_service.py` fetching real-time PM2.5, PM10, European AQI, temperature, and UV index via Open-Meteo with WAQI token support. Wired to Flutter `environmentalTelemetryProvider` with HUD capsule (`AQI 59 (Moderate) • 23°C`) and detailed sensory breakdown sheet.
- [x] **18.4 Environmental Ingestion into MCDA Engine (Completed)**: Dynamically incorporated external multi-sensor telemetry (AQI, PM2.5, PM10, UV, Solar Glare, Temp) into `backend/app/services/route_service.py`'s deterministic scoring equation ($C_e = \sum w_i S_i + H_e + A_e$). Formulated canopy protection penalties, dynamic route badges (`AQI: 65 (Moderate)`, `UV 0.0 • Partly Cloudy`), and verified with 100% passing test suite.
- [x] **18.5 Native Compass & Directional Heading Tracking (Completed)**: Implemented high-performance zero-dependency native Kotlin sensor stream in `MainActivity.kt` (`EventChannel("com.quietpath/compass")`) resolving AGP 9 build conflicts. Connected to `compassHeadingProvider`, rendering a dynamic 36° radial directional heading beam on the user beacon and live rotating azimuth FAB (`🧭 0°`).
- [ ] **18.6 Production Standalone APK Compilation**: Compile standalone release APK (`flutter build apk --release`).
- [ ] **18.7 Academic Viva Demonstration Deck**: Structured viva slides and demonstration script highlighting the 100% deterministic, explainable MCDA algorithm.
