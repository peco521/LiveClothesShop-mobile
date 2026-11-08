import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'api_error.dart';
import 'credential_store.dart';
import 'offline_sync.dart';

/// Usuario autenticado (subconjunto público de GET /api/auth/me).
class SessionUser {
  final String? empresa;
  final bool plataforma;
  final String idUsuario;
  final String? nombres;
  final String correo;
  final String rol;
  final String expiraEn;
  final String tipo;
  final List<String> permisos;
  bool get isCashier => tipo == 'E' && permisos.contains('CU24') && !plataforma;

  const SessionUser({
    required this.empresa,
    required this.plataforma,
    required this.idUsuario,
    required this.nombres,
    required this.correo,
    required this.rol,
    required this.expiraEn,
    this.tipo = 'C',
    this.permisos = const [],
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] as Map<String, dynamic>;
    final rol = json['rol'] as Map<String, dynamic>;
    return SessionUser(
      empresa: json['empresa'] as String?,
      plataforma: json['plataforma'] as bool? ?? false,
      idUsuario: usuario['idUsuario'] as String,
      nombres: usuario['nombres'] as String?,
      correo: usuario['correo'] as String,
      rol: rol['nro'] as String,
      expiraEn: json['expiraEn'] as String,
      tipo: usuario['tipo'] as String? ?? 'C',
      permisos: (json['permisos'] as List? ?? const []).cast<String>(),
    );
  }
}

enum SessionStatus { unknown, authenticated, unauthenticated }

/// Estado de sesión del cliente. Reutiliza POST /api/auth/login,
/// GET /api/auth/me y POST /api/auth/logout del backend existente.
class SessionState extends ChangeNotifier {
  final ApiClient _api;
  final CredentialStore _store;
  late final OfflineSyncQueue sync;

  SessionStatus status = SessionStatus.unknown;
  SessionUser? user;
  String? _credential;
  String? error;
  bool restoredOffline = false;

  SessionState({ApiClient? api, CredentialStore? store, OfflineQueueStorage? queueStorage})
      : _api = api ?? ApiClient(),
        _store = store ?? SecureCredentialStore(key: ApiConfig.credentialStorageKey) {
    sync = OfflineSyncQueue(api: _api, queueStorage: queueStorage);
  }

  bool get isAuthenticated => status == SessionStatus.authenticated;

  Future<void> login(String empresa, String correo, String contrasena, {bool staff = false}) async {
    sync.pause();
    _credential = null;
    user = null;
    await _store.delete();
    error = null;
    notifyListeners();
    try {
      final response = await _api.postRaw(staff ? '/api/auth/login/admin' : '/api/auth/login/cliente', {
        'empresa': empresa.trim().toLowerCase(),
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
      if (user!.plataforma || user!.empresa == null || user!.empresa!.isEmpty) {
        await _store.delete();
        _credential = null;
        user = null;
        status = SessionStatus.unauthenticated;
        error = 'La sesión no corresponde a una empresa';
        return;
      }
      await _store.writeSessionSnapshot(response.body);
      sync.activate(tenant: user!.empresa!, user: user!.idUsuario, credential: credential);
      status = SessionStatus.authenticated;
      restoredOffline = false;
      unawaited(sync.flush());
    } on ApiException catch (e) {
      _credential = null;
      user = null;
      sync.pause();
      await _store.delete();
      await _store.deleteSessionSnapshot();
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
        sync.pause();
        status = SessionStatus.unauthenticated;
        return;
      }
      final response = await _api.getRaw('/api/auth/me', credential: _credential);
      user = SessionUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      if (user!.plataforma || user!.empresa == null || user!.empresa!.isEmpty) {
        throw const ApiException(401, 'autenticacion_rechazada');
      }
      await _store.writeSessionSnapshot(response.body);
      sync.activate(tenant: user!.empresa!, user: user!.idUsuario, credential: _credential!);
      status = SessionStatus.authenticated;
      restoredOffline = false;
      unawaited(sync.flush());
    } on ApiException catch (e) {
      if (e.status == 0 && _credential != null) {
        final snapshot = await _store.readSessionSnapshot();
        if (snapshot != null) {
          try {
            user = SessionUser.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
            final expiration = DateTime.tryParse(user!.expiraEn);
            if (!user!.plataforma && user!.empresa != null && user!.empresa!.isNotEmpty
                && expiration != null && expiration.isAfter(DateTime.now())) {
              sync.activate(tenant: user!.empresa!, user: user!.idUsuario, credential: _credential!);
              status = SessionStatus.authenticated;
              restoredOffline = true;
              return;
            }
          } catch (_) {
            // Snapshot corrupto: no se usa para establecer una identidad local.
          }
        }
      }
      _credential = null;
      user = null;
      sync.pause();
      restoredOffline = false;
      if (e.status != 0) {
        await _store.delete();
        await _store.deleteSessionSnapshot();
      }
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
      sync.pause();
      error = null;
      await _store.delete();
      await _store.deleteSessionSnapshot();
      restoredOffline = false;
      status = SessionStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Credencial solo para el ApiClient interno de features (no exponer en UI).
  String? get credentialForApi => _credential;
}
