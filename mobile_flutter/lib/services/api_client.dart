import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  String? token;

  ApiClient({this.baseUrl = AppConfig.apiBaseUrl});

  Uri uri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, String> get jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Map<String, String> get authHeaders => {
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> getJson(String path) async {
    try {
      final response = await http.get(uri(path), headers: jsonHeaders).timeout(AppConfig.apiTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('Request timed out. Please check your internet connection.');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            uri(path),
            headers: jsonHeaders,
            body: jsonEncode(body),
          )
          .timeout(AppConfig.apiTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('Request timed out. Please check your internet connection.');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  Future<dynamic> multipartPost(
    String path, {
    required File file,
    required String fileField,
    Map<String, String> fields = const {},
  }) async {
    try {
      final request = http.MultipartRequest('POST', uri(path));
      request.headers.addAll(authHeaders);
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
      final streamed = await request.send().timeout(AppConfig.uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('Upload timed out. Please check your internet connection.');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {
        // Keep raw body.
      }
      throw ApiException('HTTP ${response.statusCode}: $detail', statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
