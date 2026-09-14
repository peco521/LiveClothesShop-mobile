import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'api_error.dart';
import 'credential_store.dart';

/// Usuario autenticado (subconjunto público de GET /api/auth/me).
class SessionUser {
  final String idUsuario;
  final String? nombres;
  final String correo;
  final String rol;
  final String expiraEn;

  const SessionUser({
    required this.idUsuario,
    required this.nombres,
    required this.correo,
    required this.rol,
    required this.expiraEn,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] as Map<String, dynamic>;
    final rol = json['rol'] as Map<String, dynamic>;
    return SessionUser(
      idUsuario: usuario['idUsuario'] as String,
      nombres: usuario['nombres'] as String?,
      correo: usuario['correo'] as String,
      rol: rol['nro'] as String,
      expiraEn: json['expiraEn'] as String,
    );
  }
}

enum SessionStatus { unknown, authenticated, unauthenticated }

/// Estado de sesión del cliente. Reutiliza POST /api/auth/login,
/// GET /api/auth/me y POST /api/auth/logout del backend existente.
class SessionState extends ChangeNotifier {
  final ApiClient _api;
  final CredentialStore _store;

  SessionStatus status = SessionStatus.unknown;
  SessionUser? user;
  String? _credential;
  String? error;

  SessionState({ApiClient? api, CredentialStore? store})
      : _api = api ?? ApiClient(),
        _store = store ?? SecureCredentialStore(key: ApiConfig.credentialStorageKey);

  bool get isAuthenticated => status == SessionStatus.authenticated;

  Future<void> login(String correo, String contrasena) async {
    error = null;
    notifyListeners();
    try {
      final response = await _api.postRaw('/api/auth/login', {
        'correo': correo.trim().toLowerCase(),
        'contrasena': contrasena,
      });
      final credential = ApiClient.extractCredential(response.headers['set-cookie']);
      if (credential == null) {
        throw const ApiException(500, 'credencial_no_disponible');
      }
      await _store.write(credential);
      _credential = credential;
      user = SessionUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      status = SessionStatus.authenticated;
    } on ApiException catch (e) {
      error = e.userMessage;
      status = SessionStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Restaura la sesión guardada contra GET /api/auth/me.
  Future<void> restore() async {
    try {
      _credential = await _store.read();
      if (_credential == null || _credential!.isEmpty) {
        status = SessionStatus.unauthenticated;
        return;
      }
      final response = await _api.getRaw('/api/auth/me', credential: _credential);
      user = SessionUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      status = SessionStatus.authenticated;
    } on ApiException {
      _credential = null;
      user = null;
      await _store.delete();
      status = SessionStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (_credential != null) {
        await _api.postRaw('/api/auth/logout', {}, credential: _credential);
      }
    } catch (_) {
      // Mejor esfuerzo: la sesión local siempre se limpia.
    } finally {
      _credential = null;
      user = null;
      error = null;
      await _store.delete();
      status = SessionStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Credencial solo para el ApiClient interno de features (no exponer en UI).
  String? get credentialForApi => _credential;
}
