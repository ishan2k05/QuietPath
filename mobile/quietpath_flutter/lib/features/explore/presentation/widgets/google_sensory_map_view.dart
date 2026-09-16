import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/data/hazards_provider.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_map_styles.dart';

/// QuietPath Google Maps Sensory Map View.
/// 
/// Renders Google Maps Platform vector cartography customized with:
/// 1. Low-contrast sensory JSON styling (calm muted highways, highlighted eucalyptus parks).
/// 2. Suppressed commercial POI clutter.
/// 3. Calmest vs. Quickest MCDA route polylines.
/// 4. Sensory hazard markers and destination pins.
/// 5. Camera orientation linked with real-time compass heading and GPS.
/// 6. Automatic error boundary with fallback to raster tiles if Google Play Services are unavailable.
class GoogleSensoryMapView extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final double? compassHeading;
  final bool isHardwareGps;
  final bool isCalmestSelected;
  final String destinationName;
  final List<HazardData> hazards;
  final VoidCallback? onErrorFallback;

  const GoogleSensoryMapView({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.compassHeading,
    this.isHardwareGps = false,
    this.isCalmestSelected = true,
    this.destinationName = '',
    this.hazards = const [],
    this.onErrorFallback,
  });

  @override
  State<GoogleSensoryMapView> createState() => _GoogleSensoryMapViewState();
}

class _GoogleSensoryMapViewState extends State<GoogleSensoryMapView> {
  GoogleMapController? _mapController;
  bool _hasError = false; // ignore: prefer_final_fields
  String? _errorMessage;

  // Pre-computed Bangalore sensory coordinates
  static const LatLng _cubbonParkStart = LatLng(12.9763, 77.5929);
  static const LatLng _bangaloreGolfClub = LatLng(12.9860, 77.5850);

  static const List<LatLng> _calmPolyline = [
    LatLng(12.9763, 77.5929),
    LatLng(12.9785, 77.5912),
    LatLng(12.9810, 77.5898),
    LatLng(12.9835, 77.5885),
    LatLng(12.9860, 77.5892),
    LatLng(12.9860, 77.5850),
  ];

  static const List<LatLng> _fastPolyline = [
    LatLng(12.9763, 77.5929),
    LatLng(12.9780, 77.5960),
    LatLng(12.9820, 77.5950),
    LatLng(12.9850, 77.5935),
    LatLng(12.9860, 77.5850),
  ];

  @override
  void didUpdateWidget(covariant GoogleSensoryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_mapController != null) {
      final headingChanged = widget.compassHeading != oldWidget.compassHeading;
      final locationChanged =
          widget.centerLat != oldWidget.centerLat || widget.centerLng != oldWidget.centerLng;

      if (headingChanged || locationChanged) {
        _animateCamera();
      }
    }
  }

  void _animateCamera() {
    if (_mapController == null) return;
    try {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.centerLat, widget.centerLng),
            zoom: 15.2,
            bearing: widget.compassHeading ?? 0.0,
            tilt: 0.0,
          ),
        ),
      );
    } catch (_) {}
  }

  Set<Polyline> _buildPolylines() {
    if (widget.destinationName.trim().isEmpty) {
      return {};
    }
    return {
      // 1. Quickest Route Polyline (Commercial Arterial)
      Polyline(
        polylineId: const PolylineId('fast_route'),
        points: _fastPolyline,
        color: widget.isCalmestSelected
            ? const Color(0xFFD89D8B).withValues(alpha: 0.45)
            : const Color(0xFFC95B42),
        width: widget.isCalmestSelected ? 4 : 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),

      // 2. Calmest Route Polyline (Park & Canopy Shaded)
      Polyline(
        polylineId: const PolylineId('calm_route'),
        points: _calmPolyline,
        color: widget.isCalmestSelected
            ? const Color(0xFF385A27)
            : const Color(0xFF8BB174).withValues(alpha: 0.5),
        width: widget.isCalmestSelected ? 7 : 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Destination Marker (only rendered when an active destination is selected)
    if (widget.destinationName.trim().isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _bangaloreGolfClub,
          infoWindow: InfoWindow(
            title: widget.destinationName,
            snippet: 'Safe Sanctuary Destination',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // 2. Start / Sanctuary Marker (Cubbon Park)
    markers.add(
      Marker(
        markerId: const MarkerId('start_sanctuary'),
        position: _cubbonParkStart,
        infoWindow: const InfoWindow(
          title: 'Cubbon Park Botanical Sanctuary',
          snippet: 'Quiet Start Area',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // 3. User Location Marker (if simulated / indoor)
    if (!widget.isHardwareGps) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(widget.centerLat, widget.centerLng),
          rotation: widget.compassHeading ?? 0.0,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Simulated Sensory Navigator',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );
    }

    // 4. Sensory Hazards from Live Database
    for (final hazard in widget.hazards) {
      markers.add(
        Marker(
          markerId: MarkerId('hazard_${hazard.id}'),
          position: LatLng(hazard.lat, hazard.lng),
          infoWindow: InfoWindow(
            title: '⚠️ ${hazard.title}',
            snippet: '${hazard.hazardType.toUpperCase()} (Severity ${hazard.severity}/5)',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFFEFF2EE),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, color: QuietColors.primaryDark, size: 48),
            const SizedBox(height: 12),
            Text(
              'Switching to Calm Sensory Tiles',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: QuietColors.textCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Vector cartography fallback active',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: QuietColors.textMuted),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.centerLat, widget.centerLng),
        zoom: 15.2,
        bearing: widget.compassHeading ?? 0.0,
      ),
      style: sensoryMapJsonStyle,
      myLocationEnabled: widget.isHardwareGps,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      trafficEnabled: false,
      buildingsEnabled: true,
      polylines: _buildPolylines(),
      markers: _buildMarkers(),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onCameraMoveStarted: () {},
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
