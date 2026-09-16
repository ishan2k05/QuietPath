import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/services/geocoding_service.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/data/hazards_provider.dart';
import 'package:quietpath_flutter/features/explore/data/environmental_provider.dart';
import 'package:quietpath_flutter/features/explore/data/routes_provider.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_map_canvas.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_tile_layer.dart';
import 'package:quietpath_flutter/features/navigation/services/tts_service.dart';
import 'package:quietpath_flutter/core/widgets/quietpath_logo.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/voice_search_modal.dart';

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  String? _currentDestination;
  final TransformationController _transformationController = TransformationController();
  MapDisplayMode _mapDisplayMode = MapDisplayMode.googleMaps;
  bool _showSensoryZones = true;
  String? _selectedHazardId;
  bool _isRouteSheetExpanded = false;
  double _cameraLat = 12.9770;
  double _cameraLng = 77.5910;
  double _cameraZoom = 14.0;
  double _startScaleZoom = 14.0;
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    final cfg = AppConfigService();
    _mapDisplayMode = cfg.mapDisplayMode;
    _showSensoryZones = cfg.showSensoryCanopy;
    _currentDestination = null; // Always start in clean empty state upon open/reopen

    // Detect user's real physical/network location upon launch (e.g. Pune)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final locNotifier = ref.read(userLocationProvider.notifier);
      final detected = await locNotifier.detectAndApplyRealLocation();
      if (mounted) {
        final UserCoordinates loc = detected ?? ref.read(userLocationProvider);
        setState(() {
          _cameraLat = loc.latitude;
          _cameraLng = loc.longitude;
        });

        // Ensure routes are clear on launch (pure exploratory mode)
        ref.read(routesProvider.notifier).clearRoutes();
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _recenterMap() async {
    final userLoc = ref.read(userLocationProvider);
    setState(() {
      _cameraLat = userLoc.latitude;
      _cameraLng = userLoc.longitude;
      _cameraZoom = 15.0;
    });
    await ref.read(userLocationProvider.notifier).toggleHardwareGps();
  }



  void _toggleGoogleMapsMode() {
    setState(() {
      if (_mapDisplayMode == MapDisplayMode.googleMaps) {
        _mapDisplayMode = MapDisplayMode.streetTiles;
      } else {
        _mapDisplayMode = MapDisplayMode.googleMaps;
      }
    });
    AppConfigService().setMapDisplayMode(_mapDisplayMode);

    final label = _mapDisplayMode == MapDisplayMode.googleMaps
        ? 'Google Maps (Sensory Vector)'
        : 'Street Tiles (Esri World)';
    _showMapModeSnackBar(label);
  }

  void _toggleTileCanvasMode() {
    setState(() {
      if (_mapDisplayMode == MapDisplayMode.pureCanvas) {
        _mapDisplayMode = MapDisplayMode.streetTiles;
      } else {
        _mapDisplayMode = MapDisplayMode.pureCanvas;
      }
    });
    AppConfigService().setMapDisplayMode(_mapDisplayMode);

    final label = _mapDisplayMode == MapDisplayMode.pureCanvas
        ? 'Calm Vector Canvas'
        : 'Street Tiles (Esri World)';
    _showMapModeSnackBar(label);
  }

  void _showMapModeSnackBar(String label) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _mapDisplayMode == MapDisplayMode.googleMaps
                  ? Icons.map_rounded
                  : (_mapDisplayMode == MapDisplayMode.streetTiles
                      ? Icons.layers_rounded
                      : Icons.brush_rounded),
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: QuietColors.textCharcoal,
      ),
    );
  }

  void _selectAndNavigate(String destName, [double? lat, double? lng, String? label]) {
    if (lat != null && lng != null) {
      LocationService.registerDestination(destName, lat, lng, label);
    }
    final coord = LocationService.destinationCoordinates[destName];
    setState(() {
      _currentDestination = destName;
      if (coord != null) {
        final userLoc = ref.read(userLocationProvider);
        _cameraLat = (userLoc.latitude + coord.latitude) / 2;
        _cameraLng = (userLoc.longitude + coord.longitude) / 2;
        _cameraZoom = 14.0;
      }
    });
    AppConfigService().setCurrentDestination(destName);
    ref.read(routesProvider.notifier).fetchRoutes(
      destName: destName,
      destLat: coord?.latitude,
      destLng: coord?.longitude,
    );
    TtsService().speakCalm('Destination set to $destName. Calculating calm route.');
  }

  void _clearDestination() {
    setState(() {
      _currentDestination = null;
      _isRouteSheetExpanded = false;
    });
    AppConfigService().setCurrentDestination('');
    ref.read(routesProvider.notifier).clearRoutes();
    LocationService.clearActiveRouteWaypoints();
    TtsService().speakCalm('Route cleared. Exploring calm surroundings.');
  }

  Future<void> _openVoiceSearch() async {
    final result = await VoiceSearchModal.show(context);
    if (result != null && result.trim().isNotEmpty) {
      final query = result.trim();
      final userLocation = ref.read(userLocationProvider);
      final results = await GeocodingService().searchPlaces(
        query,
        userLat: userLocation.latitude,
        userLng: userLocation.longitude,
      );
      if (results.isNotEmpty) {
        final top = results.first;
        _selectAndNavigate(top.name, top.latitude, top.longitude, top.formattedAddress);
      } else {
        _selectAndNavigate(query);
      }
    }
  }

  void _openSearchSheet() {
    final userLocation = ref.read(userLocationProvider);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        String selectedCategory = 'All';
        bool isSearching = false;
        Timer? debounceTimer;
        List<PlaceSearchResult> currentResults = GeocodingService.getSuggestionsForLocation(
          userLat: userLocation.latitude,
          userLng: userLocation.longitude,
        );

        void selectAndNavigate(String destName, [double? lat, double? lng, String? label]) {
          Navigator.pop(ctx);
          _selectAndNavigate(destName, lat, lng, label);
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = currentResults.where((place) {
              if (selectedCategory == 'All') return true;
              return place.category == selectedCategory;
            }).toList();

            final hasCustomQuery = searchQuery.trim().isNotEmpty &&
                !currentResults.any((p) => p.name.toLowerCase() == searchQuery.trim().toLowerCase());

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Row with Live Telemetry Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Places & Sanctuaries',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: QuietColors.textCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: userLocation.isHardwareGps
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              userLocation.isHardwareGps
                                  ? Icons.gps_fixed_rounded
                                  : Icons.near_me_rounded,
                              size: 12,
                              color: userLocation.isHardwareGps
                                  ? QuietColors.primaryDark
                                  : const Color(0xFF1565C0),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userLocation.isHardwareGps ? 'Live Hardware GPS' : 'Sensory GPS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: userLocation.isHardwareGps
                                    ? QuietColors.primaryDark
                                    : const Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Universal Autocomplete Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E7E2)),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: GoogleFonts.inter(fontSize: 14, color: QuietColors.textCharcoal),
                      decoration: InputDecoration(
                        hintText: 'Search any address, city, landmark, coordinates...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: QuietColors.textMuted),
                        prefixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: QuietColors.primaryDark,
                                  ),
                                ),
                              )
                            : const Icon(Icons.search_rounded, color: QuietColors.primaryDark, size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: QuietColors.textMuted),
                                onPressed: () {
                                  searchController.clear();
                                  debounceTimer?.cancel();
                                  setSheetState(() {
                                    searchQuery = '';
                                    isSearching = false;
                                    currentResults = GeocodingService.getSuggestionsForLocation(
                                      userLat: userLocation.latitude,
                                      userLng: userLocation.longitude,
                                    );
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.mic_rounded, size: 20, color: QuietColors.primaryDark),
                              tooltip: 'Sensory Voice Search',
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openVoiceSearch();
                              },
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        setSheetState(() => searchQuery = val);
                        debounceTimer?.cancel();
                        if (val.trim().isEmpty) {
                          setSheetState(() {
                            isSearching = false;
                            currentResults = GeocodingService.getSuggestionsForLocation(
                              userLat: userLocation.latitude,
                              userLng: userLocation.longitude,
                            );
                          });
                        } else {
                          final instantLocal = GeocodingService.getLocalMatches(
                            val.trim(),
                            userLat: userLocation.latitude,
                            userLng: userLocation.longitude,
                          );
                          setSheetState(() {
                            isSearching = true;
                            if (instantLocal.isNotEmpty) {
                              currentResults = instantLocal;
                            }
                          });
                          debounceTimer = Timer(const Duration(milliseconds: 320), () async {
                            final results = await GeocodingService().searchPlaces(
                              val.trim(),
                              userLat: userLocation.latitude,
                              userLng: userLocation.longitude,
                            );
                            if (ctx.mounted) {
                              setSheetState(() {
                                isSearching = false;
                                currentResults = results;
                              });
                            }
                          });
                        }
                      },
                      onSubmitted: (val) async {
                        final query = val.trim();
                        if (query.isNotEmpty) {
                          final results = await GeocodingService().searchPlaces(
                            query,
                            userLat: userLocation.latitude,
                            userLng: userLocation.longitude,
                          );
                          if (results.isNotEmpty) {
                            final top = results.first;
                            selectAndNavigate(top.name, top.latitude, top.longitude, top.formattedAddress);
                          } else {
                            selectAndNavigate(query);
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Parks & Greenery',
                        'Safe Space / Library',
                        'Sanctuaries',
                        'Water Promenades',
                      ].map((cat) {
                        final isSel = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? Colors.white : QuietColors.textCharcoal,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: QuietColors.primaryDark,
                            backgroundColor: const Color(0xFFF1F3F1),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => selectedCategory = cat);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Results List
                  Expanded(
                    child: ListView(
                      children: [
                        // Custom GPS Target / Coordinate entry option
                        if (hasCustomQuery) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_location_alt_rounded, color: QuietColors.primaryDark, size: 20),
                            ),
                            title: Text(
                              'Navigate to "$searchQuery"',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: QuietColors.primaryDark,
                              ),
                            ),
                            subtitle: Text(
                              'Global coordinates / custom destination routing',
                              style: GoogleFonts.inter(fontSize: 11, color: QuietColors.textMuted),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: QuietColors.primaryDark),
                            onTap: () async {
                              final results = await GeocodingService().searchPlaces(
                                searchQuery.trim(),
                                userLat: userLocation.latitude,
                                userLng: userLocation.longitude,
                              );
                              if (results.isNotEmpty) {
                                final top = results.first;
                                selectAndNavigate(top.name, top.latitude, top.longitude, top.formattedAddress);
                              } else {
                                selectAndNavigate(searchQuery.trim());
                              }
                            },
                          ),
                          const Divider(height: 12),
                        ],

                        // Global & Sanctuary Places Results
                        ...filtered.map((place) {
                          final isSelected = place.name == _currentDestination;
                          final distanceMeters = LocationService.calculateDistanceMeters(
                            userLocation.latitude,
                            userLocation.longitude,
                            place.latitude,
                            place.longitude,
                          );
                          final distanceStr = distanceMeters >= 1000
                              ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
                              : '${distanceMeters.round()} m';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? QuietColors.primaryLight : const Color(0xFFF1F3F5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                place.isCuratedSanctuary
                                    ? Icons.spa_rounded
                                    : Icons.location_on_rounded,
                                color: isSelected ? QuietColors.primaryDark : QuietColors.textCharcoal,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: QuietColors.textCharcoal,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (place.sensoryScore != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: place.sensoryScore! >= 80
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${place.sensoryScore!.round()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: place.sensoryScore! >= 80
                                            ? QuietColors.primaryDark
                                            : const Color(0xFFE65100),
                                      ),
                                    ),
                                  ),
                                ],
                                Text(
                                  distanceStr,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: QuietColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      place.formattedAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 11, color: QuietColors.textMuted),
                                    ),
                                  ),
                                  if (place.badge.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F6F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        place.badge,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: QuietColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: QuietColors.textMuted),
                            onTap: () => selectAndNavigate(
                              place.name,
                              place.latitude,
                              place.longitude,
                              place.formattedAddress,
                            ),
                          );
                        }),

                        if (filtered.isEmpty && !hasCustomQuery)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                isSearching
                                    ? 'Searching global places & calm routes...'
                                    : 'No matching locations found.\nType any place, city, or coordinates worldwide.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: QuietColors.textMuted),
                              ),
                            ),
                          ),
                      ],
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
                        color: Colors.grey.withValues(alpha: 0.3),
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
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
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
                        final trimmedTitle = titleController.text.trim();
                        final sanitizedTitle = trimmedTitle.length >= 3
                            ? (trimmedTitle.length <= 120 ? trimmedTitle : trimmedTitle.substring(0, 120))
                            : 'Sensory Disruption';
                        final userLoc = ref.read(userLocationProvider);

                        final success = await ref.read(hazardsProvider.notifier).reportHazard(
                          hazardType: selectedType,
                          title: sanitizedTitle,
                          description: descController.text.trim(),
                          severity: severity.toInt(),
                          lat: userLoc.latitude,
                          lng: userLoc.longitude,
                        );

                        if (mounted) {
                          final hState = ref.read(hazardsProvider);
                          final msg = success
                              ? (hState.successMessage ?? 'Hazard reported! Real-time routes updated.')
                              : (hState.errorMessage ?? 'Unable to record hazard at this time.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: success ? QuietColors.primaryDark : QuietColors.alertRed,
                              content: Text(
                                msg,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          if (success) {
                            ref.read(routesProvider.notifier).fetchRoutes();
                          }
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
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
                      color: Colors.grey.withValues(alpha: 0.3),
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

              // Surrounding Micro-Climates (Live Multi-Sensor Readings)
              Builder(
                builder: (context) {
                  final surroundings = ref.watch(surroundingsTelemetryProvider).value?.zones ??
                      SurroundingsTelemetry.defaultSurroundings.zones;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Surrounding Micro-Climates (Live)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: QuietColors.textCharcoal,
                            ),
                          ),
                          Text(
                            'Real-time Open-Meteo',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: QuietColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...surroundings.map((z) {
                        final isGreen = z.type == 'green_canopy';
                        final isWater = z.type == 'water_promenade';
                        final badgeColor = isGreen
                            ? const Color(0xFF2E7D32)
                            : (isWater ? const Color(0xFF0288D1) : const Color(0xFFD97706));
                        final badgeBg = isGreen
                            ? const Color(0xFFF1F8F1)
                            : (isWater ? const Color(0xFFE1F5FE) : const Color(0xFFFFF8E1));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE6ECE6)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isGreen
                                      ? Icons.eco_rounded
                                      : (isWater ? Icons.water_drop_rounded : Icons.traffic_rounded),
                                  size: 16,
                                  color: badgeColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      z.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: QuietColors.textCharcoal,
                                      ),
                                    ),
                                    Text(
                                      z.condition,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: QuietColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AQI ${z.aqi} • ${z.temperatureC.round()}°C',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
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

    final targetCoords = LocationService.destinationCoordinates[_currentDestination];
    final calcDistM = targetCoords != null
        ? LocationService.calculateDistanceMeters(
            userLocation.latitude, userLocation.longitude, targetCoords.latitude, targetCoords.longitude)
        : 2400.0;
    final fallbackDistKm = math.max(0.4, double.parse((calcDistM / 1000.0).toStringAsFixed(1)));
    final fallbackCalmMins = math.max(3, (fallbackDistKm / 4.2 * 60).round());
    final fallbackFastMins = math.max(2, (fallbackDistKm / 5.0 * 60).round());

    final calmRoute = routesState.routes.isNotEmpty
        ? routesState.routes.firstWhere((r) => r.isRecommended, orElse: () => routesState.routes.first)
        : RouteOptionData(
            id: 'route_calmest',
            name: 'Calmest Route',
            durationMinutes: fallbackCalmMins,
            distanceKm: fallbackDistKm,
            sensoryScore: 87.0,
            isRecommended: true,
            isFastest: false,
            badges: ['★ Recommended for You', 'Low Noise Corridor', 'Low Crowd'],
            turnInstructions: ['Turn right onto calm pathway'],
            factorBreakdown: {
              'noise': {'impact_percentage': 14.0},
              'crowd': {'impact_percentage': 18.0},
              'traffic': {'impact_percentage': 9.0},
              'construction': {'impact_percentage': 4.0},
              'light': {'impact_percentage': 20.0},
              'air_quality': {'impact_percentage': 28.0},
            },
          );

    final fastRoute = routesState.routes.length > 1
        ? routesState.routes.firstWhere((r) => r.isFastest, orElse: () => routesState.routes.last)
        : RouteOptionData(
            id: 'route_fastest',
            name: 'Quickest Route',
            durationMinutes: fallbackFastMins,
            distanceKm: math.max(0.3, double.parse((fallbackDistKm * 0.9).toStringAsFixed(1))),
            sensoryScore: 42.0,
            isRecommended: false,
            isFastest: true,
            badges: ['Quickest Route', 'High Traffic'],
            turnInstructions: ['Head straight on main road'],
            factorBreakdown: {
              'noise': {'impact_percentage': 32.0},
              'crowd': {'impact_percentage': 22.0},
              'traffic': {'impact_percentage': 25.0},
              'construction': {'impact_percentage': 16.0},
              'light': {'impact_percentage': 18.0},
              'air_quality': {'impact_percentage': 30.0},
            },
          );

    return Scaffold(
      backgroundColor: QuietColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Map View (Google Maps Platform / Esri Street Tiles / Pure Vector Canvas)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasTiles = _mapDisplayMode != MapDisplayMode.pureCanvas;
                final tileProvider = _mapDisplayMode == MapDisplayMode.googleMaps
                    ? TileProviderType.googleRoads
                    : TileProviderType.esriStreet;
                final surroundingsAsync = ref.watch(surroundingsTelemetryProvider);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    _startScaleZoom = _cameraZoom;
                    _lastFocalPoint = details.focalPoint;
                  },
                  onScaleUpdate: (details) {
                    if (_lastFocalPoint == null) return;
                    final delta = details.focalPoint - _lastFocalPoint!;
                    _lastFocalPoint = details.focalPoint;

                    // 1. Pan adjustment in Web Mercator coordinates
                    final currentPxX = MercatorProjection.lngToPixelX(_cameraLng, _cameraZoom);
                    final currentPxY = MercatorProjection.latToPixelY(_cameraLat, _cameraZoom);

                    final newPxX = currentPxX - delta.dx;
                    final newPxY = currentPxY - delta.dy;

                    final newLng = MercatorProjection.pixelXToLng(newPxX, _cameraZoom);
                    final newLat = MercatorProjection.pixelYToLat(newPxY, _cameraZoom);

                    // 2. Pinch zoom adjustment
                    double newZoom = _cameraZoom;
                    if (details.scale != 1.0) {
                      newZoom = (_startScaleZoom + math.log(details.scale) / math.ln2).clamp(3.0, 19.0);
                    }

                    setState(() {
                      _cameraLat = newLat.clamp(-85.0, 85.0);
                      _cameraLng = newLng.clamp(-180.0, 180.0);
                      _cameraZoom = newZoom;
                    });
                  },
                  onScaleEnd: (details) {
                    _lastFocalPoint = null;
                  },
                  onTapUp: (details) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    for (final h in hazardsState.hazards) {
                      final hOffset = SensoryMapCanvas.getHazardOffset(
                        h,
                        size,
                        hasTileLayer: hasTiles,
                        cameraLat: _cameraLat,
                        cameraLng: _cameraLng,
                        zoom: _cameraZoom,
                      );
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
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      children: [
                        // Real-time Procedural Slippy Street Map Layer
                        if (hasTiles)
                          Positioned.fill(
                            child: SensoryTileLayer(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              centerLat: _cameraLat,
                              centerLng: _cameraLng,
                              zoom: _cameraZoom,
                              providerType: tileProvider,
                              opacity: _mapDisplayMode == MapDisplayMode.googleMaps ? 0.95 : 0.85,
                            ),
                          ),

                        // Interactive Sensory Vector Canvas with Geo-Anchored Routes
                        Positioned.fill(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final compassHeading = ref.watch(compassHeadingProvider);
                              return SensoryMapCanvas(
                                isCalmestSelected: isCalmestSelected,
                                destinationName: _currentDestination ?? '',
                                hazards: hazardsState.hazards,
                                showSensoryZones: _showSensoryZones,
                                selectedHazardId: _selectedHazardId,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                hasTileLayer: hasTiles,
                                isHardwareGps: userLocation.isHardwareGps,
                                userLat: userLocation.latitude,
                                userLng: userLocation.longitude,
                                accuracy: userLocation.accuracy,
                                heading: compassHeading,
                                cameraLat: _cameraLat,
                                cameraLng: _cameraLng,
                                zoom: _cameraZoom,
                                surroundingZones: surroundingsAsync.value?.zones,
                              );
                            },
                          ),
                        ),

                        // Google Maps Attribution Badge (in Google Maps mode)
                        if (_mapDisplayMode == MapDisplayMode.googleMaps)
                          Positioned(
                            left: 14,
                            bottom: 110,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                'Google',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF5F6368),
                                  letterSpacing: -0.5,
                                ),
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
            top: MediaQuery.of(context).padding.top + 162,
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
                  icon: Icons.map_rounded,
                  tooltip: _mapDisplayMode == MapDisplayMode.googleMaps
                      ? 'Google Maps Active (Tap to switch to tiles)'
                      : 'Switch to Google Maps',
                  isActive: _mapDisplayMode == MapDisplayMode.googleMaps,
                  onTap: _toggleGoogleMapsMode,
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: _mapDisplayMode == MapDisplayMode.pureCanvas
                      ? Icons.brush_rounded
                      : Icons.layers_rounded,
                  tooltip: _mapDisplayMode == MapDisplayMode.pureCanvas
                      ? 'Calm Canvas Active (Tap for Street Tiles)'
                      : 'Street Tiles Active (Tap for Canvas)',
                  isActive: _mapDisplayMode == MapDisplayMode.streetTiles,
                  onTap: _toggleTileCanvasMode,
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final compassHeading = ref.watch(compassHeadingProvider);
                    if (compassHeading == null) return const SizedBox.shrink();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        _buildMapActionButton(
                          icon: Icons.navigation_rounded,
                          tooltip: 'Compass: ${compassHeading.round()}° (Tap to calibrate)',
                          iconRotation: compassHeading * (math.pi / 180.0),
                          onTap: () {
                            ref.read(compassHeadingProvider.notifier).setHeading(0.0);
                          },
                        ),
                      ],
                    );
                  },
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const QuietPathLogo(size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'QuietPath',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: QuietColors.primaryDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _openReportHazardSheet,
                        child: const Icon(Icons.emergency_share_outlined, color: QuietColors.textCharcoal, size: 20),
                      ),
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
                Container(
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
                      GestureDetector(
                        onTap: _openSearchSheet,
                        behavior: HitTestBehavior.opaque,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded, color: QuietColors.textMuted, size: 22),
                            SizedBox(width: 10),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _openSearchSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            (_currentDestination != null && _currentDestination!.trim().isNotEmpty)
                                ? _currentDestination!
                                : 'Where would you like to go calmly?',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: (_currentDestination != null && _currentDestination!.trim().isNotEmpty)
                                  ? QuietColors.textCharcoal
                                  : QuietColors.textMuted,
                              fontWeight: (_currentDestination != null && _currentDestination!.trim().isNotEmpty)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (_currentDestination != null && _currentDestination!.trim().isNotEmpty)
                        GestureDetector(
                          onTap: _clearDestination,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Icon(Icons.close_rounded, color: QuietColors.textMuted, size: 20),
                          ),
                        ),
                      GestureDetector(
                        onTap: _openVoiceSearch,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(Icons.mic_rounded, color: QuietColors.primaryDark, size: 21),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openSearchSheet,
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(Icons.near_me_rounded, color: QuietColors.primaryDark, size: 20),
                      ),
                    ],
                  ),
                ),

                // Live Environmental Telemetry Capsule (AQI & Temperature only)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                                  const SizedBox(width: 6),
                                  Text(
                                    'AQI ${env.aqiIndex} • ${env.temperatureC.round()}°C',
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

          // 4. Collapsible Bottom Route Overlay OR Exploratory Sanctuary Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: (_currentDestination != null && _currentDestination!.trim().isNotEmpty)
                ? AnimatedContainer(
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
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isCalmestSelected
                                            ? QuietColors.primaryLight
                                            : const Color(0xFFF1F3F5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.near_me_rounded,
                                        size: 18,
                                        color: isCalmestSelected
                                            ? QuietColors.primaryDark
                                            : QuietColors.textCharcoal,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _currentDestination ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: QuietColors.textCharcoal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isCalmestSelected
                                                ? '${calmRoute.name} • ${calmRoute.durationMinutes}m (${calmRoute.distanceKm.toStringAsFixed(1)} km)'
                                                : '${fastRoute.name} • ${fastRoute.durationMinutes}m (${fastRoute.distanceKm.toStringAsFixed(1)} km)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: QuietColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                        'Compare (${routesState.routes.isNotEmpty ? routesState.routes.length : 2})',
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
                            title: calmRoute.name,
                            duration: '${calmRoute.durationMinutes} mins',
                            sublabel: '${calmRoute.distanceKm.toStringAsFixed(1)} km',
                            score: '${calmRoute.sensoryScore.round()}',
                            onTap: () => ref.read(routesProvider.notifier).selectRoute(calmRoute.id),
                            onExplain: () => _showExplainabilitySheet(context, calmRoute),
                          ),
                          const SizedBox(height: 8),

                          // Card 2: Quickest Route
                          _buildRouteCard(
                            context: context,
                            isRecommended: false,
                            isSelected: !isCalmestSelected,
                            title: fastRoute.name,
                            duration: '${fastRoute.durationMinutes} mins',
                            sublabel: '${fastRoute.distanceKm.toStringAsFixed(1)} km',
                            score: '${fastRoute.sensoryScore.round()}',
                            onTap: () => ref.read(routesProvider.notifier).selectRoute(fastRoute.id),
                            onExplain: () => _showExplainabilitySheet(context, fastRoute),
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
                              final chosenRoute = isCalmestSelected ? calmRoute : fastRoute;
                              TtsService().speakCalm('Starting navigation to ${_currentDestination ?? 'Destination'} via ${chosenRoute.name}.');
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
                  )
                : _buildExploratorySanctuaryBar(),
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
    double? iconRotation,
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
          child: iconRotation != null
              ? Transform.rotate(
                  angle: iconRotation,
                  child: Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.white : QuietColors.textCharcoal,
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : QuietColors.textCharcoal,
                ),
        ),
      ),
    );
  }

  Widget _buildExploratorySanctuaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: QuietColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa_rounded, size: 16, color: QuietColors.primaryDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sensory Calm Mode Active',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: QuietColors.textCharcoal,
                      ),
                    ),
                    Text(
                      'Tap a sanctuary below or search any place to route',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: QuietColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _openSearchSheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Browse',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: QuietColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickExploreChip('🌿 Empress Botanical', 'Empress Botanical Garden'),
                const SizedBox(width: 8),
                _buildQuickExploreChip('🧘 Osho Teerth', 'Osho Teerth Park'),
                const SizedBox(width: 8),
                _buildQuickExploreChip('🏛️ Quiet Library', 'State Central Library'),
                const SizedBox(width: 8),
                _buildQuickExploreChip('🌳 Vetal Hill', 'Vetal Tekdi Hill'),
                const SizedBox(width: 8),
                _buildQuickExploreChip('🌸 Kamala Nehru', 'Kamala Nehru Park'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickExploreChip(String label, String destination) {
    return ActionChip(
      avatar: const Icon(Icons.near_me_rounded, size: 13, color: QuietColors.primaryDark),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: QuietColors.textCharcoal,
        ),
      ),
      backgroundColor: const Color(0xFFEDF4ED),
      side: const BorderSide(color: Color(0xFFCCE0CB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: () => _selectAndNavigate(destination),
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
                    color: Colors.grey.withValues(alpha: 0.3),
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

