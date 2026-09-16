import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:quietpath_flutter/features/profile/data/profile_models.dart';

/// Map cartography display mode:
/// - googleMaps: Google Maps Platform vector map with custom low-contrast sensory styling
/// - streetTiles: High-resolution Esri World Street / OSM slippy raster tiles
/// - pureCanvas: Abstract low-stimulus sensory vector canvas
enum MapDisplayMode {
  googleMaps,
  streetTiles,
  pureCanvas,
}

/// Persistent on-device configuration and user preferences service.
/// Stores sensory profile, onboarding status, and UI settings locally in JSON format.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  bool _initialized = false;
  File? _configFile;

  // Configuration state with sensory defaults
  bool _hasCompletedOnboarding = false;
  SensoryProfile _sensoryProfile = SensoryProfile(
    noiseSensitivity: 0.5,
    crowdComfort: 0.5,
    lightIntensity: 0.5,
    trafficSensitivity: 0.5,
    timePenaltyTolerance: 0.5,
  );
  MapDisplayMode _mapDisplayMode = MapDisplayMode.googleMaps;
  bool _showStreetTiles = true;
  bool _showSensoryCanopy = true;
  bool _autoRerouteEnabled = true;
  bool _ttsVoiceEnabled = true;
  double _lastKnownLat = 18.510408;
  double _lastKnownLng = 73.937475;
  String _currentDestination = '';
  String _serverBaseUrl = '';

  // Getters
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  SensoryProfile get sensoryProfile => _sensoryProfile;
  MapDisplayMode get mapDisplayMode => _mapDisplayMode;
  bool get showStreetTiles => _showStreetTiles;
  bool get showSensoryCanopy => _showSensoryCanopy;
  bool get autoRerouteEnabled => _autoRerouteEnabled;
  bool get ttsVoiceEnabled => _ttsVoiceEnabled;
  double get lastKnownLat => _lastKnownLat;
  double get lastKnownLng => _lastKnownLng;
  String get currentDestination => _currentDestination;
  String get serverBaseUrl => _serverBaseUrl;

  /// Resolves the app storage file location across platforms
  File _resolveConfigFile() {
    if (_configFile != null) return _configFile!;

    try {
      if (Platform.isAndroid) {
        // Standard Android internal app data directory
        final androidDir = Directory('/data/user/0/com.example.quietpath_flutter/files');
        if (androidDir.existsSync()) {
          _configFile = File('${androidDir.path}/quietpath_config.json');
          return _configFile!;
        }
        final fallbackDir = Directory('/data/data/com.example.quietpath_flutter/files');
        if (fallbackDir.existsSync()) {
          _configFile = File('${fallbackDir.path}/quietpath_config.json');
          return _configFile!;
        }
      }
    } catch (_) {
      // Ignore security errors during platform checks
    }

    // Universal fallback: system temporary / working directory
    final tempDir = Directory.systemTemp;
    _configFile = File('${tempDir.path}/quietpath_config.json');
    return _configFile!;
  }

  /// Initializes the service and loads stored preferences from disk.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final file = _resolveConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          _parseJson(jsonMap);
          debugPrint('[AppConfigService] Loaded local config from ${file.path}');
        }
      } else {
        debugPrint('[AppConfigService] No existing config found. Using fresh defaults.');
      }
    } catch (e) {
      debugPrint('[AppConfigService] Error reading config: $e. Falling back to defaults.');
    }

    _initialized = true;
  }

  void _parseJson(Map<String, dynamic> json) {
    if (json.containsKey('has_completed_onboarding')) {
      _hasCompletedOnboarding = json['has_completed_onboarding'] as bool? ?? false;
    }
    if (json.containsKey('sensory_profile')) {
      final profileJson = json['sensory_profile'] as Map<String, dynamic>?;
      if (profileJson != null) {
        _sensoryProfile = SensoryProfile.fromJson(profileJson);
      }
    }
    if (json.containsKey('map_display_mode')) {
      final modeStr = json['map_display_mode'] as String?;
      if (modeStr == 'googleMaps') {
        _mapDisplayMode = MapDisplayMode.googleMaps;
      } else if (modeStr == 'streetTiles') {
        _mapDisplayMode = MapDisplayMode.streetTiles;
      } else if (modeStr == 'pureCanvas') {
        _mapDisplayMode = MapDisplayMode.pureCanvas;
      }
    }
    if (json.containsKey('show_street_tiles')) {
      _showStreetTiles = json['show_street_tiles'] as bool? ?? true;
    }
    if (json.containsKey('show_sensory_canopy')) {
      _showSensoryCanopy = json['show_sensory_canopy'] as bool? ?? true;
    }
    if (json.containsKey('auto_reroute_enabled')) {
      _autoRerouteEnabled = json['auto_reroute_enabled'] as bool? ?? true;
    }
    if (json.containsKey('tts_voice_enabled')) {
      _ttsVoiceEnabled = json['tts_voice_enabled'] as bool? ?? true;
    }
    if (json.containsKey('last_known_lat')) {
      _lastKnownLat = (json['last_known_lat'] as num?)?.toDouble() ?? 12.9716;
    }
    if (json.containsKey('last_known_lng')) {
      _lastKnownLng = (json['last_known_lng'] as num?)?.toDouble() ?? 77.5946;
    }
    if (json.containsKey('current_destination')) {
      // Current destination is session-transient; on fresh cold launch it always starts empty
      _currentDestination = '';
    }
    if (json.containsKey('server_base_url')) {
      _serverBaseUrl = json['server_base_url'] as String? ?? '';
    }
  }

  Map<String, dynamic> _toJson() {
    return {
      'has_completed_onboarding': _hasCompletedOnboarding,
      'sensory_profile': _sensoryProfile.toJson(),
      'map_display_mode': _mapDisplayMode.name,
      'show_street_tiles': _showStreetTiles,
      'show_sensory_canopy': _showSensoryCanopy,
      'auto_reroute_enabled': _autoRerouteEnabled,
      'tts_voice_enabled': _ttsVoiceEnabled,
      'last_known_lat': _lastKnownLat,
      'last_known_lng': _lastKnownLng,
      'current_destination': _currentDestination,
      'server_base_url': _serverBaseUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Sets custom backend server base URL and persists immediately.
  Future<void> setServerBaseUrl(String url) async {
    _serverBaseUrl = url.trim();
    await save();
  }

  Timer? _debounceSaveTimer;

  void _scheduleDebouncedSave() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(seconds: 15), () {
      save();
    });
  }

  /// Asynchronously saves the current config to disk.
  Future<void> save() async {
    _debounceSaveTimer?.cancel();
    try {
      final file = _resolveConfigFile();
      if (!file.parent.existsSync()) {
        try {
          file.parent.createSync(recursive: true);
        } catch (_) {}
      }
      final jsonString = jsonEncode(_toJson());
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('[AppConfigService] Failed to write config: $e');
    }
  }

  /// Sets onboarding status and persists immediately.
  Future<void> setOnboardingCompleted(bool value) async {
    _hasCompletedOnboarding = value;
    await save();
  }

  /// Updates sensory profile and persists immediately.
  Future<void> updateSensoryProfile(SensoryProfile profile) async {
    _sensoryProfile = profile;
    await save();
  }

  /// Updates map cartography mode.
  Future<void> setMapDisplayMode(MapDisplayMode mode) async {
    _mapDisplayMode = mode;
    _showStreetTiles = mode != MapDisplayMode.pureCanvas;
    await save();
  }

  /// Updates street tiles visibility.
  Future<void> setStreetTiles(bool value) async {
    _showStreetTiles = value;
    if (!value && _mapDisplayMode != MapDisplayMode.pureCanvas) {
      _mapDisplayMode = MapDisplayMode.pureCanvas;
    }
    await save();
  }
  Future<void> setShowStreetTiles(bool value) => setStreetTiles(value);

  /// Updates sensory canopy visibility.
  Future<void> setSensoryCanopy(bool value) async {
    _showSensoryCanopy = value;
    await save();
  }
  Future<void> setShowSensoryCanopy(bool value) => setSensoryCanopy(value);

  /// Updates auto-reroute setting.
  Future<void> setAutoReroute(bool value) async {
    _autoRerouteEnabled = value;
    await save();
  }

  /// Updates TTS voice setting.
  Future<void> setTtsVoice(bool value) async {
    _ttsVoiceEnabled = value;
    await save();
  }
  Future<void> setTtsVoiceEnabled(bool value) => setTtsVoice(value);

  /// Updates user location in-memory immediately, debouncing disk writes
  /// to eliminate flash I/O lag and stutter during active tracking.
  Future<void> updateLocation(double lat, double lng) async {
    _lastKnownLat = lat;
    _lastKnownLng = lng;
    _scheduleDebouncedSave();
  }
  Future<void> updateLastLocation(double lat, double lng) => updateLocation(lat, lng);

  /// Updates current destination.
  Future<void> setDestination(String dest) async {
    _currentDestination = dest;
    await save();
  }
  Future<void> setCurrentDestination(String dest) => setDestination(dest);

  /// Resets config to initial state (useful for test resets).
  Future<void> reset() async {
    _hasCompletedOnboarding = false;
    _sensoryProfile = SensoryProfile();
    _showStreetTiles = true;
    _showSensoryCanopy = true;
    _autoRerouteEnabled = true;
    _ttsVoiceEnabled = true;
    _lastKnownLat = 12.9716;
    _lastKnownLng = 77.5946;
    _currentDestination = '';
    await save();
  }
}
