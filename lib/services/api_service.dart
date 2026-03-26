import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  /// ─── IMPORTANT: Automatic local host detection for testing.
  /// For Android Emulator → 10.0.2.2
  /// For Web / Desktop / iOS Simulator → 127.0.0.1 or localhost
  static const String _defaultHost = '192.168.1.36';
  static const int _serverPort = 8000;

  static String get baseUrl {
    // 10.0.2.2 is the special alias to your host loopback interface for Android emulators
    if (!kIsWeb && Platform.isAndroid && _defaultHost == '127.0.0.1') {
      return 'http://10.0.2.2:$_serverPort/api';
    }
    return 'http://$_defaultHost:$_serverPort/api';
  }
  // static String get baseUrl => 'https://intigrity-bell-backend.vercel.app/api';

  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static String? get currentToken => _token;

  static Map<String, String> _buildHeaders({String? token}) {
    final effectiveToken = token ?? _token;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveToken';
    }
    return headers;
  }

  // GET
  static Future<http.Response> get(String endpoint, {String? token}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      debugPrint('[API GET] $uri');
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(const Duration(seconds: 15));
      debugPrint('[API GET] ${response.statusCode} $endpoint');
      return response;
    } catch (e) {
      debugPrint('[API GET ERROR] $endpoint → $e');
      rethrow;
    }
  }

  // POST
  static Future<http.Response> post(String endpoint, Map<String, dynamic> body,
      {String? token}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      debugPrint('[API POST] $uri');
      final response = await http
          .post(uri, headers: _buildHeaders(token: token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      debugPrint('[API POST] ${response.statusCode} $endpoint');
      return response;
    } catch (e) {
      debugPrint('[API POST ERROR] $endpoint → $e');
      rethrow;
    }
  }

  // PUT
  static Future<http.Response> put(String endpoint, Map<String, dynamic> body,
      {String? token}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      debugPrint('[API PUT] $uri');
      final response = await http
          .put(uri, headers: _buildHeaders(token: token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      debugPrint('[API PUT] ${response.statusCode} $endpoint');
      return response;
    } catch (e) {
      debugPrint('[API PUT ERROR] $endpoint → $e');
      rethrow;
    }
  }

  // DELETE
  static Future<http.Response> delete(String endpoint, {String? token}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      debugPrint('[API DELETE] $uri');
      final response = await http
          .delete(uri, headers: _buildHeaders(token: token))
          .timeout(const Duration(seconds: 15));
      debugPrint('[API DELETE] ${response.statusCode} $endpoint');
      return response;
    } catch (e) {
      debugPrint('[API DELETE ERROR] $endpoint → $e');
      rethrow;
    }
  }

  // Multipart POST (for file uploads)
  static Future<http.StreamedResponse> postMultipart(
    String endpoint,
    Map<String, String> fields, {
    List<String>? filePaths,
    String? fileField = 'file',
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);
    final effectiveToken = token ?? _token;
    if (effectiveToken != null) {
      request.headers['Authorization'] = 'Bearer $effectiveToken';
    }
    debugPrint('🎙️ postMultipart: $uri');
    debugPrint('🎙️ postMultipart headers: ${request.headers}');
    request.fields.addAll(fields);
    if (filePaths != null) {
      for (var path in filePaths) {
        request.files.add(await http.MultipartFile.fromPath(fileField!, path));
      }
    }
    return await request.send();
  }
}
