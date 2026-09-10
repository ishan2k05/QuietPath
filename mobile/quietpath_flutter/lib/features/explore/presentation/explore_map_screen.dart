import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/data/hazards_provider.dart';
import 'package:quietpath_flutter/features/explore/data/environmental_provider.dart';
import 'package:quietpath_flutter/features/explore/data/routes_provider.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_map_canvas.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_tile_layer.dart';
import 'package:quietpath_flutter/features/navigation/services/tts_service.dart';

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  String _currentDestination = 'Bangalore Golf Club';
  final TransformationController _transformationController = TransformationController();
  bool _showSensoryZones = true;
  bool _showTileLayer = true;
  String? _selectedHazardId;
  bool _isRouteSheetExpanded = false;

  @override
  void initState() {
    super.initState();
    final cfg = AppConfigService();
    _showSensoryZones = cfg.showSensoryCanopy;
    _showTileLayer = cfg.showStreetTiles;
    _currentDestination = cfg.currentDestination;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _recenterMap() async {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
    await ref.read(userLocationProvider.notifier).toggleHardwareGps();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1.25);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scale(0.8);
    _transformationController.value = matrix;
  }

  void _toggleSensoryZones() {
    setState(() {
      _showSensoryZones = !_showSensoryZones;
    });
    AppConfigService().setShowSensoryCanopy(_showSensoryZones);
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final destinations = [
          {
            'name': 'Bangalore Golf Club',
            'address': 'Sankey Road, High Grounds, Bengaluru',
            'category': 'Recreation / Green Space',
            'badge': 'Low Noise',
          },
          {
            'name': 'Cubbon Park Sanctuary',
            'address': 'Kasturba Road, Sampangi Rama Nagara, Bengaluru',
            'category': 'Park / Nature Sanctuary',
            'badge': 'Very Quiet',
          },
          {
            'name': 'Lalbagh Botanical Garden',
            'address': 'Mavalli, Bengaluru',
            'category': 'Botanical Conservatory',
            'badge': 'Low Stimulus',
          },
          {
            'name': 'Central Public Library',
            'address': 'Cubbon Park, Bengaluru',
            'category': 'Safe Space / Library',
            'badge': 'Silence Required',
          },
          {
            'name': 'Commercial Street',
            'address': 'Tasker Town, Shivaji Nagar, Bengaluru',
            'category': 'Commercial Center',
            'badge': 'High Noise',
          },
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Destination',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: QuietColors.textCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              ...destinations.map((dest) {
                final isSelected = dest['name'] == _currentDestination;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? QuietColors.primaryLight : const Color(0xFFF1F3F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: isSelected ? QuietColors.primaryDark : QuietColors.textCharcoal,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    dest['name']!,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  subtitle: Text(
                    dest['address']!,
                    style: GoogleFonts.inter(fontSize: 12, color: QuietColors.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F6F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dest['badge']!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: QuietColors.primaryDark,
                      ),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _currentDestination = dest['name']!;
                    });
                    AppConfigService().setCurrentDestination(_currentDestination);
                    ref.read(routesProvider.notifier).fetchRoutes();
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _openReportHazardSheet() {
    String selectedType = 'construction';
    double severity = 3.0;
    final titleController = TextEditingController(text: 'Roadwork & Drilling');
    final descController = TextEditingController(text: 'Active machinery causing sensory noise spike');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF1EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_alert_rounded, color: QuietColors.alertRed, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Sensory Incident',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: QuietColors.textCharcoal,
                            ),
                          ),
                          Text(
                            'Alerts other sensitive navigators in real-time',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: QuietColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Stimulus Type',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {
                        'type': 'construction',
                        'label': '🚧 Construction',
                        'color': const Color(0xFFD97706),
                      },
                      {
                        'type': 'noise',
                        'label': '📢 Noise Surge',
                        'color': QuietColors.alertRed,
                      },
                      {
                        'type': 'crowd',
                        'label': '👥 Crowded Area',
                        'color': QuietColors.secondary,
                      },
                      {
                        'type': 'light',
                        'label': '💡 Harsh Light',
                        'color': const Color(0xFFEAB308),
                      },
                    ].map((item) {
                      final isSelected = selectedType == item['type'];
                      return ChoiceChip(
                        label: Text(
                          item['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : QuietColors.textCharcoal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: QuietColors.primaryDark,
                        backgroundColor: const Color(0xFFF1F3F5),
                        showCheckmark: false,
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = item['type'] as String;
                              if (selectedType == 'construction') {
                                titleController.text = 'Roadwork & Drilling';
                              } else if (selectedType == 'noise') {
                                titleController.text = 'Loud Music & Siren';
                              } else if (selectedType == 'crowd') {
                                titleController.text = 'Heavy Gathering Surge';
                              } else if (selectedType == 'light') {
                                titleController.text = 'High Glare Floodlights';
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Severity Level: ${severity.toInt()}/5',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: QuietColors.textCharcoal,
                        ),
                      ),
                      Text(
                        severity > 3 ? 'Distressing' : 'Noticeable',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: severity > 3 ? QuietColors.alertRed : QuietColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: severity > 3 ? QuietColors.alertRed : QuietColors.primaryDark,
                      thumbColor: severity > 3 ? QuietColors.alertRed : QuietColors.primaryDark,
                      inactiveTrackColor: const Color(0xFFE5E7EB),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: severity,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (val) {
                        setSheetState(() => severity = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Title / Incident',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuietColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(hazardsProvider.notifier).reportHazard(
                          hazardType: selectedType,
                          title: titleController.text.trim().isNotEmpty
                              ? titleController.text.trim()
                              : 'Sensory Hazard',
                          description: descController.text.trim(),
                          severity: severity.toInt(),
                          lat: 12.9755,
                          lng: 77.5925,
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: QuietColors.primaryDark,
                              content: Text(
                                'Hazard reported! Real-time routes updated to avoid stimulus.',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          ref.read(routesProvider.notifier).fetchRoutes();
                        }
                      },
                      child: Text(
                        'Broadcast Hazard Alert',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEnvironmentalSheet(EnvironmentalTelemetry telemetry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Color aqiBadgeColor = const Color(0xFF2E7D32);
        Color aqiBgColor = const Color(0xFFE8F5E9);
        if (telemetry.aqiIndex > 100) {
          aqiBadgeColor = const Color(0xFFD32F2F);
          aqiBgColor = const Color(0xFFFFEBEE);
        } else if (telemetry.aqiIndex > 50) {
          aqiBadgeColor = const Color(0xFFD97706);
          aqiBgColor = const Color(0xFFFEF3C7);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF1EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.air_rounded, color: QuietColors.primaryDark, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sensory Environment',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: QuietColors.textCharcoal,
                                ),
                              ),
                              Text(
                                'Live atmospheric telemetry',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: QuietColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: aqiBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AQI ${telemetry.aqiIndex} • ${telemetry.aqiCategory}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: aqiBadgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Metric Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _buildEnvironmentalMetricCard(
                      label: 'PM2.5 / PM10',
                      value: '${telemetry.pm25.toStringAsFixed(1)} / ${telemetry.pm10.toStringAsFixed(1)}',
                      unit: 'µg/m³',
                      icon: Icons.grain_rounded,
                      iconColor: const Color(0xFF0288D1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEnvironmentalMetricCard(
                      label: 'Temperature',
                      value: '${telemetry.temperatureC.toStringAsFixed(1)}°C',
                      unit: telemetry.weatherCondition,
                      icon: Icons.wb_sunny_outlined,
                      iconColor: const Color(0xFFF57C00),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEnvironmentalMetricCard(
                      label: 'UV Index',
                      value: telemetry.uvIndex.toStringAsFixed(1),
                      unit: telemetry.uvIndex > 5 ? 'High UV' : 'Moderate',
                      icon: Icons.wb_twilight_rounded,
                      iconColor: const Color(0xFF7B1FA2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sensory Implications
              if (telemetry.sensoryImplications.isNotEmpty) ...[
                Text(
                  'Sensory Route Implications',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: QuietColors.textCharcoal,
                  ),
                ),
                const SizedBox(height: 6),
                ...telemetry.sensoryImplications.map((imp) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: QuietColors.primaryDark, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          imp,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: QuietColors.textCharcoal,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
              ],

              // Recommended Gear
              if (telemetry.recommendedGear.isNotEmpty) ...[
                Text(
                  'Recommended Gear for Calmer Journey',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: QuietColors.textCharcoal,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: telemetry.recommendedGear.map((gear) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD6DFD6)),
                    ),
                    child: Text(
                      gear,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: QuietColors.primaryDark,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentalMetricCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EBE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: QuietColors.textMuted,
                  ),
                ),
              ),
              Icon(icon, size: 14, color: iconColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: QuietColors.textCharcoal,
            ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: QuietColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routesState = ref.watch(routesProvider);
    final hazardsState = ref.watch(hazardsProvider);
    final userLocation = ref.watch(userLocationProvider);
    final isCalmestSelected =
        routesState.selectedRouteId == 'route_calmest' || routesState.selectedRouteId == null;

    return Scaffold(
      backgroundColor: QuietColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Interactive Sensory Map Canvas (Pan, Pinch-to-Zoom, Recenter)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(350),
                  minScale: 0.75,
                  maxScale: 3.5,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      children: [
                        // Real-time Slippy Street Map Layer (Esri Street / OSM)
                        if (_showTileLayer)
                          Positioned.fill(
                            child: SensoryTileLayer(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              centerLat: userLocation.latitude,
                              centerLng: userLocation.longitude,
                              providerType: TileProviderType.esriStreet,
                            ),
                          ),

                        // Interactive Sensory Vector Canvas & Tap Detection
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              final size = Size(constraints.maxWidth, constraints.maxHeight);
                              for (final h in hazardsState.hazards) {
                                final hOffset = SensoryMapCanvas.getHazardOffset(h, size);
                                if ((details.localPosition - hOffset).distance <= 36) {
                                  setState(() {
                                    _selectedHazardId = (_selectedHazardId == h.id) ? null : h.id;
                                  });
                                  return;
                                }
                              }
                              if (_selectedHazardId != null) {
                                setState(() {
                                  _selectedHazardId = null;
                                });
                              }
                            },
                            child: SensoryMapCanvas(
                              isCalmestSelected: isCalmestSelected,
                              destinationName: _currentDestination,
                              hazards: hazardsState.hazards,
                              showSensoryZones: _showSensoryZones,
                              selectedHazardId: _selectedHazardId,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              hasTileLayer: _showTileLayer,
                              isHardwareGps: userLocation.isHardwareGps,
                              userLat: userLocation.latitude,
                              userLng: userLocation.longitude,
                              accuracy: userLocation.accuracy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Floating Map Navigation & Layer Action Controls
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapActionButton(
                  icon: userLocation.isHardwareGps
                      ? Icons.gps_fixed_rounded
                      : Icons.my_location_rounded,
                  tooltip: userLocation.isHardwareGps
                      ? 'Live Hardware GPS Active (Tap to toggle)'
                      : 'Recenter / Enable Hardware GPS',
                  isActive: userLocation.isHardwareGps,
                  onTap: _recenterMap,
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Toggle Real-Time Street Map',
                  isActive: _showTileLayer,
                  onTap: () {
                    setState(() {
                      _showTileLayer = !_showTileLayer;
                    });
                    AppConfigService().setShowStreetTiles(_showTileLayer);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: Icons.park_outlined,
                  tooltip: 'Toggle Sensory Canopy Shading',
                  isActive: _showSensoryZones,
                  onTap: _toggleSensoryZones,
                ),
              ],
            ),
          ),

          // 3. Top Translucent Soft Grey-Out Header Bar (Shields QuietPath branding from map tile lines)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 6,
                    bottom: 10,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2EE).withValues(alpha: 0.92),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFCBD6CA).withValues(alpha: 0.90),
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.hearing_rounded, color: QuietColors.primaryDark, size: 20),
                      Text(
                        'QuietPath',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: QuietColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Icon(Icons.emergency_share_outlined, color: QuietColors.textCharcoal, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Floating Search Bar & Live Alerts Capsule (Floats cleanly below translucent header)
          Positioned(
            top: MediaQuery.of(context).padding.top + 54,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Search Pill
                GestureDetector(
                  onTap: _openSearchSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: QuietColors.textMuted, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentDestination,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: QuietColors.textCharcoal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.near_me_rounded, color: QuietColors.primaryDark, size: 20),
                      ],
                    ),
                  ),
                ),

                // Minimalist Live Alerts Capsule & Live Environmental Telemetry
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hazardsState.hazards.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${hazardsState.hazards.length} Live Alerts',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: QuietColors.textCharcoal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _openReportHazardSheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: QuietColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '+ Report',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: QuietColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (hazardsState.hazards.isNotEmpty)
                          const SizedBox(width: 8),

                        // Live Environmental Telemetry Capsule
                        Builder(
                          builder: (context) {
                            final envAsync = ref.watch(environmentalTelemetryProvider);
                            final env = envAsync.value ?? EnvironmentalTelemetry.defaultTelemetry;
                            Color aqiIconColor = const Color(0xFF2E7D32);
                            if (env.aqiIndex > 100) {
                              aqiIconColor = const Color(0xFFD32F2F);
                            } else if (env.aqiIndex > 50) {
                              aqiIconColor = const Color(0xFFD97706);
                            }

                            return GestureDetector(
                              onTap: () => _openEnvironmentalSheet(env),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.air_rounded, size: 14, color: aqiIconColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      'AQI ${env.aqiIndex} (${env.aqiCategory}) • ${env.temperatureC.round()}°C',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: QuietColors.textCharcoal,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 13,
                                      color: QuietColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        if (userLocation.isHardwareGps) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF90CAF9)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.satellite_alt_rounded, size: 12, color: Color(0xFF1565C0)),
                                const SizedBox(width: 4),
                                Text(
                                  'Live GPS',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Selected Hazard Detail Callout Card
                if (_selectedHazardId != null) ...[
                  Builder(
                    builder: (context) {
                      final hazard = hazardsState.hazards
                          .where((h) => h.id == _selectedHazardId)
                          .firstOrNull;
                      if (hazard == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: hazard.tagColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: hazard.tagColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.warning_amber_rounded, size: 16, color: hazard.tagColor),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hazard.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: QuietColors.textCharcoal,
                                    ),
                                  ),
                                  Text(
                                    '${hazard.hazardType.toUpperCase()} • Severity ${hazard.severity}/5',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: QuietColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => setState(() => _selectedHazardId = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F3F5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 14, color: QuietColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // 4. Collapsible Bottom Route Overlay (Peek mode leaves map open)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isRouteSheetExpanded) ...[
                    // Compact Peek Mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isCalmestSelected
                                    ? QuietColors.primaryLight
                                    : const Color(0xFFFDE8E4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isCalmestSelected ? 'Score 87' : 'Score 42',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCalmestSelected
                                      ? QuietColors.primaryDark
                                      : QuietColors.alertRed,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCalmestSelected ? 'Calmest Route' : 'Quickest Route',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: QuietColors.textCharcoal,
                                  ),
                                ),
                                Text(
                                  isCalmestSelected ? '16 mins • 2.4 km • Shaded' : '12 mins • 2.1 km • Arterial',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: QuietColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => setState(() => _isRouteSheetExpanded = true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Compare (2)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: QuietColors.textCharcoal,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: QuietColors.textCharcoal),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Expanded Comparison Mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Route Comparison',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: QuietColors.textCharcoal,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isRouteSheetExpanded = false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Row(
                              children: [
                                Text(
                                  'Collapse',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: QuietColors.textMuted,
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: QuietColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Card 1: Calmest Route
                    _buildRouteCard(
                      context: context,
                      isRecommended: true,
                      isSelected: isCalmestSelected,
                      title: 'Calmest Route',
                      duration: '16 mins',
                      sublabel: '2.4 km',
                      score: '87',
                      onTap: () => ref.read(routesProvider.notifier).selectRoute('route_calmest'),
                      onExplain: () {
                        final calm = routesState.routes.isNotEmpty
                            ? routesState.routes.firstWhere((r) => r.isRecommended, orElse: () => routesState.routes.first)
                            : RouteOptionData(
                                id: 'route_calmest',
                                name: 'Calmest Route',
                                durationMinutes: 16,
                                distanceKm: 2.4,
                                sensoryScore: 87.0,
                                isRecommended: true,
                                isFastest: false,
                                badges: ['★ Recommended for You', 'Low Noise', 'Low Crowd'],
                                turnInstructions: ['Turn right onto Oak Trail'],
                                factorBreakdown: {
                                  'noise': {'impact_percentage': 14.0},
                                  'crowd': {'impact_percentage': 18.0},
                                  'traffic': {'impact_percentage': 9.0},
                                  'construction': {'impact_percentage': 4.0},
                                  'light': {'impact_percentage': 20.0},
                                  'air_quality': {'impact_percentage': 28.0},
                                },
                              );
                        _showExplainabilitySheet(context, calm);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Card 2: Quickest Route
                    _buildRouteCard(
                      context: context,
                      isRecommended: false,
                      isSelected: !isCalmestSelected,
                      title: 'Quickest Route',
                      duration: '12 mins',
                      sublabel: '2.1 km',
                      score: '42',
                      onTap: () => ref.read(routesProvider.notifier).selectRoute('route_fastest'),
                      onExplain: () {
                        final fast = routesState.routes.length > 1
                            ? routesState.routes.firstWhere((r) => r.isFastest, orElse: () => routesState.routes.last)
                            : RouteOptionData(
                                id: 'route_fastest',
                                name: 'Quickest Route',
                                durationMinutes: 12,
                                distanceKm: 2.1,
                                sensoryScore: 42.0,
                                isRecommended: false,
                                isFastest: true,
                                badges: ['Quickest Route', 'High Traffic'],
                                turnInstructions: ['Head north on Commercial Main Road'],
                                factorBreakdown: {
                                  'noise': {'impact_percentage': 32.0},
                                  'crowd': {'impact_percentage': 22.0},
                                  'traffic': {'impact_percentage': 25.0},
                                  'construction': {'impact_percentage': 16.0},
                                  'light': {'impact_percentage': 18.0},
                                  'air_quality': {'impact_percentage': 30.0},
                                },
                              );
                        _showExplainabilitySheet(context, fast);
                      },
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Start Navigation Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuietColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        alignment: Alignment.center,
                      ),
                      onPressed: () {
                        TtsService().speakCalm('Starting navigation to $_currentDestination via Calmest Route.');
                        context.push(
                          '/navigation',
                          extra: {'destination': _currentDestination},
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Start Navigation',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isActive ? QuietColors.primaryDark : Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? Colors.white : QuietColors.textCharcoal,
          ),
        ),
      ),
    );
  }


  void _showExplainabilitySheet(BuildContext context, RouteOptionData route) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final dynamic rawBreakdown = route.factorBreakdown;
        double getImpact(String key, double fallback) {
          try {
            if (rawBreakdown is Map && rawBreakdown[key] is Map) {
              final val = rawBreakdown[key]['impact_percentage'];
              if (val is num) return val.toDouble();
            }
          } catch (_) {}
          return fallback;
        }

        final noiseImpact = getImpact('noise', 14.0);
        final crowdImpact = getImpact('crowd', 18.0);
        final trafficImpact = getImpact('traffic', 9.0);
        final constructionImpact = getImpact('construction', 4.0);
        final lightImpact = getImpact('light', 20.0);
        final aqiImpact = getImpact('air_quality', 28.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sensory Score Breakdown',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: route.isRecommended ? QuietColors.primaryLight : const Color(0xFFFDE8E4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Score ${route.sensoryScore.toInt()}/100',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: route.isRecommended ? QuietColors.primaryDark : QuietColors.alertRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Deterministic MCDA Model: Mathematical Multi-Criteria Decision Analysis explains why ${route.name} received this comfort rating.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: QuietColors.textMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Factor Rows
              _buildFactorRow('Noise Exposure', Icons.volume_down_rounded, noiseImpact, route.isRecommended ? QuietColors.primaryDark : const Color(0xFFE5533D)),
              _buildFactorRow('Crowd Density', Icons.groups_rounded, crowdImpact, route.isRecommended ? const Color(0xFF4A7C59) : const Color(0xFFE5533D)),
              _buildFactorRow('Traffic Congestion', Icons.directions_car_rounded, trafficImpact, route.isRecommended ? const Color(0xFF5B8E7D) : const Color(0xFFE5533D)),
              _buildFactorRow('Construction Alerts', Icons.construction_rounded, constructionImpact, const Color(0xFFD97706)),
              _buildFactorRow('Glare & Lighting', Icons.wb_sunny_outlined, lightImpact, const Color(0xFF6B7280)),
              _buildFactorRow('Air Quality & Particulates', Icons.air_rounded, aqiImpact, const Color(0xFF456B34)),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: QuietColors.primaryDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Algorithm: Pure deterministic MCDA with real-time Open-Meteo AQI. Strictly 0% black-box generative AI.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: QuietColors.textCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF456B34),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close Breakdown',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFactorRow(String label, IconData icon, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                ],
              ),
              Text(
                '${percentage.toStringAsFixed(1)}% penalty impact',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF1F3F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard({
    required BuildContext context,
    required bool isRecommended,
    required bool isSelected,
    required String title,
    required String duration,
    required String sublabel,
    required String score,
    required VoidCallback onTap,
    VoidCallback? onExplain,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? QuietColors.primaryDark : QuietColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.03),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: QuietColors.textCharcoal,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ Best',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$duration • $sublabel',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: QuietColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Sensory Score Badge & Info Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onExplain,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRecommended ? QuietColors.primaryLight : const Color(0xFFFDE8E4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Score $score',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isRecommended ? QuietColors.primaryDark : QuietColors.alertRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.info_outline_rounded, size: 18, color: QuietColors.textMuted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Clean, uncluttered stimulus tags
            Row(
              children: [
                _buildStimulusPill(
                  icon: isRecommended ? Icons.park_outlined : Icons.volume_up_outlined,
                  label: isRecommended ? 'Quiet Canopy' : 'High Noise',
                  isGood: isRecommended,
                ),
                const SizedBox(width: 8),
                _buildStimulusPill(
                  icon: isRecommended ? Icons.people_outline_rounded : Icons.traffic_rounded,
                  label: isRecommended ? 'Low Crowd' : 'Heavy Traffic',
                  isGood: isRecommended,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStimulusPill({
    required IconData icon,
    required String label,
    required bool isGood,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGood ? const Color(0xFFF1F6F0) : const Color(0xFFFBF1EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isGood ? QuietColors.primaryDark : QuietColors.alertRed,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isGood ? QuietColors.primaryDark : QuietColors.alertRed,
            ),
          ),
        ],
      ),
    );
  }
}

