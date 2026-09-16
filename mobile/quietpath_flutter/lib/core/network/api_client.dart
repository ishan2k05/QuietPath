import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  String get baseUrl => dio.options.baseUrl;

  void updateBaseUrl(String newUrl) {
    String formatted = newUrl.trim();
    if (formatted.isNotEmpty) {
      if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
        formatted = 'http://$formatted';
      }
      if (!formatted.endsWith('/api/v1') && !formatted.endsWith('/api/v1/')) {
        if (formatted.endsWith('/')) {
          formatted = '${formatted}api/v1';
        } else {
          formatted = '$formatted/api/v1';
        }
      }
      dio.options.baseUrl = formatted;
      debugPrint('[ApiClient] Updated baseUrl to: $formatted');
    }
  }

  ApiClient._internal() {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final savedBaseUrl = AppConfigService().serverBaseUrl;

    String baseUrl = savedBaseUrl.isNotEmpty
        ? savedBaseUrl
        : (envBaseUrl.isNotEmpty ? envBaseUrl : 'http://127.0.0.1:8000/api/v1');

    if (savedBaseUrl.isEmpty && envBaseUrl.isEmpty && !kIsWeb) {
      if (Platform.isAndroid) {
        // Android emulator loopback to host PC
        baseUrl = 'http://10.0.2.2:8000/api/v1';
      } else if (Platform.isIOS) {
        baseUrl = 'http://127.0.0.1:8000/api/v1';
      }
    }

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }
}
