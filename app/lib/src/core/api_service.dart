import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'env.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppEnv.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.read(dioProvider));
});

class ApiService {
  ApiService(this._dio);

  final Dio _dio;

  Future<dynamic> get(
    String path, {
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: _options(token),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: data,
      options: _options(token),
    );
    return _mapResponse(response.data);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    String? token,
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.patch<dynamic>(
      path,
      data: data,
      options: _options(token),
    );
    return _mapResponse(response.data);
  }

  Future<void> delete(String path, {String? token}) async {
    await _dio.delete<dynamic>(path, options: _options(token));
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    required List<MultipartFile> files,
    String? token,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: FormData.fromMap({...fields, 'files': files}),
      options: _options(token),
    );
    return _mapResponse(response.data);
  }

  Future<List<int>> downloadBytes(String path, {required String token}) async {
    final response = await _dio.get<List<int>>(
      path,
      options: _options(token).copyWith(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final base = _dio.options.baseUrl.endsWith('/')
        ? _dio.options.baseUrl.substring(0, _dio.options.baseUrl.length - 1)
        : _dio.options.baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }

  Options _options(String? token) {
    return Options(
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _mapResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
      final fallback = data['error'];
      if (fallback is String && fallback.trim().isNotEmpty) {
        return fallback;
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'تعذّر الاتصال بالسيرفر. تأكد من اتصالك بالإنترنت.\nConnection to the server failed.';
    }
  }

  return error.toString();
}
