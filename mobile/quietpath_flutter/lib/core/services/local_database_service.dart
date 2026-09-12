import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';

/// Lightweight, high-performance persistent local JSON database.
/// Stored inside the APK's internal app files sandbox for global offline persistence across launches.
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Directory? _dbDir;
  bool _isInitialized = false;

  // In-memory collection caches for synchronous ultra-fast reads
  final Map<String, dynamic> _settingsCache = {};
  final Map<String, dynamic> _userLocationCache = {};
  final List<Map<String, dynamic>> _placesCache = [];
  final Map<String, dynamic> _routesCache = {};
  final List<Map<String, dynamic>> _safeSpacesCache = [];

  Future<Directory> get dbDir async {
    if (_dbDir != null) return _dbDir!;
    final baseDir = Directory.systemTemp;
    final dir = Directory('${baseDir.path}/quietpath_database');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dbDir = dir;
    return dir;
  }

  /// Initializes local database and hydrates in-memory caches from disk
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final dir = await dbDir;
      await _loadCollection(dir, 'settings', _settingsCache);
      await _loadCollection(dir, 'user_location', _userLocationCache);
      await _loadCollection(dir, 'routes', _routesCache);
      await _loadListCollection(dir, 'places', _placesCache);
      await _loadListCollection(dir, 'safe_spaces', _safeSpacesCache);
      _isInitialized = true;
      debugPrint('[LocalDB] Initialized successfully at ${dir.path}');
    } catch (e) {
      debugPrint('[LocalDB] Initialization error: $e');
    }
  }

  Future<void> _loadCollection(Directory dir, String name, Map<String, dynamic> target) async {
    try {
      final file = File('${dir.path}/$name.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            target.addAll(decoded);
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalDB] Error loading $name: $e');
    }
  }

  Future<void> _loadListCollection(Directory dir, String name, List<Map<String, dynamic>> target) async {
    try {
      final file = File('${dir.path}/$name.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            target.clear();
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                target.add(item);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalDB] Error loading list $name: $e');
    }
  }

  Future<void> _saveCollection(String name, dynamic data) async {
    try {
      final dir = await dbDir;
      final file = File('${dir.path}/$name.json');
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[LocalDB] Error writing $name: $e');
    }
  }

  // ================= User Location Persistence =================

  /// Retrieves the persisted real-time user coordinates from disk
  UserCoordinates? getPersistedUserLocation() {
    if (_userLocationCache.isEmpty) return null;
    try {
      final lat = (_userLocationCache['latitude'] as num?)?.toDouble();
      final lng = (_userLocationCache['longitude'] as num?)?.toDouble();
      final label = _userLocationCache['label'] as String? ?? 'Current Location';
      final isHardware = _userLocationCache['isHardwareGps'] as bool? ?? false;
      if (lat != null && lng != null) {
        return UserCoordinates(
          latitude: lat,
          longitude: lng,
          label: label,
          isHardwareGps: isHardware,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Persists user coordinates with detected city / region
  Future<void> saveUserLocation(UserCoordinates coords, {String? city}) async {
    _userLocationCache['latitude'] = coords.latitude;
    _userLocationCache['longitude'] = coords.longitude;
    _userLocationCache['label'] = coords.label;
    _userLocationCache['isHardwareGps'] = coords.isHardwareGps;
    _userLocationCache['city'] = city ?? coords.label;
    _userLocationCache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveCollection('user_location', _userLocationCache);
  }

  // ================= App Settings Persistence =================

  dynamic getSetting(String key, [dynamic defaultValue]) {
    return _settingsCache[key] ?? defaultValue;
  }

  Future<void> setSetting(String key, dynamic value) async {
    _settingsCache[key] = value;
    await _saveCollection('settings', _settingsCache);
  }

  // ================= Places & Sanctuaries Offline Cache =================

  List<Map<String, dynamic>> getCachedPlaces() {
    return List.unmodifiable(_placesCache);
  }

  Future<void> savePlaces(List<Map<String, dynamic>> places) async {
    _placesCache.clear();
    _placesCache.addAll(places);
    await _saveCollection('places', _placesCache);
  }

  // ================= Routes Offline Cache =================

  Map<String, dynamic>? getCachedRoute(String origin, String destination) {
    final key = '${origin.trim().toLowerCase()}->${destination.trim().toLowerCase()}';
    final data = _routesCache[key];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  Future<void> saveRoute(String origin, String destination, Map<String, dynamic> routeData) async {
    final key = '${origin.trim().toLowerCase()}->${destination.trim().toLowerCase()}';
    _routesCache[key] = {
      ...routeData,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _saveCollection('routes', _routesCache);
  }

  // ================= Safe Spaces Cache =================

  List<Map<String, dynamic>> getCachedSafeSpaces() {
    return List.unmodifiable(_safeSpacesCache);
  }

  Future<void> saveSafeSpaces(List<Map<String, dynamic>> spaces) async {
    _safeSpacesCache.clear();
    _safeSpacesCache.addAll(spaces);
    await _saveCollection('safe_spaces', _safeSpacesCache);
  }
}
