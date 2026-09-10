import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    String baseUrl = envBaseUrl.isNotEmpty ? envBaseUrl : 'http://127.0.0.1:8000/api/v1';

    if (envBaseUrl.isEmpty && !kIsWeb) {
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
