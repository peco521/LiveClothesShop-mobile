import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_error.dart';

/// Cliente HTTP mínimo contra LiveClothesShop-api.
///
/// Autenticación móvil: el login entrega la credencial de sesión SOLO en la
/// cabecera `Set-Cookie` (HttpOnly: el navegador la guarda solo; una app
/// nativa SÍ puede leer la cabecera). Se extrae con [extractCredential] y se
/// reenvía como `Authorization: Bearer`, mecanismo ya aceptado por el backend
/// (`current_credential`). Nunca se envían cookie y Bearer a la vez.
class ApiClient {
  final http.Client _http;
  final String baseUrl;
  final String origin;

  ApiClient({http.Client? httpClient, String? baseUrl, String? origin})
      : _http = httpClient ?? http.Client(),
        baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/$'), ''),
        origin = origin ?? ApiConfig.origin;

  /// Extrae la credencial de sesión desde `Set-Cookie` sin debilitar nada:
  /// la cookie web sigue siendo HttpOnly; aquí solo se lee la cabecera.
  /// Retorna null si no hay credencial con formato válido (43 caracteres).
  static String? extractCredential(String? setCookie, [String cookieName = ApiConfig.cookieName]) {
    if (setCookie == null || setCookie.isEmpty) return null;
    final match = RegExp('$cookieName="?([A-Za-z0-9_-]{43})"?').firstMatch(setCookie);
    return match?.group(1);
  }

  Map<String, String> _headers({String? credential, bool mutation = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (credential != null && credential.isNotEmpty) {
      headers['Authorization'] = 'Bearer $credential';
    }
    if (mutation) {
      headers['Origin'] = origin;
      headers['X-CSRF-Protection'] = '1';
    }
    return headers;
  }

  Never _throwForStatus(http.Response response) {
    String code = 'error_desconocido';
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['code'] is String) code = error['code'] as String;
      }
    } catch (_) {
      // Cuerpo no JSON: se conserva solo el estado.
    }
    throw ApiException(response.statusCode, code);
  }

  void _check(http.Response response) {
    if (response.statusCode >= 400) _throwForStatus(response);
  }

  Future<http.Response> getRaw(
    String path, {
    Map<String, String>? query,
    String? credential,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query?.isEmpty ?? true ? null : query);
    try {
      final response = await _http.get(uri, headers: _headers(credential: credential));
      _check(response);
      return response;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'error_conexion');
    }
  }

  Future<http.Response> postRaw(
    String path,
    Map<String, dynamic> body, {
    String? credential,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _http.post(uri,
          headers: _headers(credential: credential, mutation: true), body: jsonEncode(body));
      _check(response);
      return response;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'error_conexion');
    }
  }

  Future<http.Response> patchRaw(
    String path,
    Map<String, dynamic> body, {
    String? credential,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _http.patch(uri,
          headers: _headers(credential: credential, mutation: true), body: jsonEncode(body));
      _check(response);
      return response;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'error_conexion');
    }
  }

  Future<http.Response> deleteRaw(String path, {String? credential}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response =
          await _http.delete(uri, headers: _headers(credential: credential, mutation: true));
      _check(response);
      return response;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'error_conexion');
    }
  }

  void close() => _http.close();
}
