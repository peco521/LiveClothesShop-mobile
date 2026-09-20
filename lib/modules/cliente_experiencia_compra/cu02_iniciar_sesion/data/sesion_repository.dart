import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../../shared/models/sesion.dart';

/// CU02 (iniciar sesión) + consulta de la sesión vigente.
///
/// La sesión del backend es una cookie HttpOnly: el repositorio nunca lee su
/// valor, solo llama a los endpoints y deja que cookie_jar la reenvíe.
class SesionRepository {
  const SesionRepository(this._client);

  final ApiClient _client;

  Future<Sesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login/cliente',
      body: {'correo': correo.trim(), 'contrasena': contrasena},
    );
    return Sesion.fromJson(response.data ?? const {});
  }

  /// Restaura la sesión al abrir la app (cookie persistida). `null` si no hay.
  Future<Sesion?> sesionActual() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/auth/me');
      return Sesion.fromJson(response.data ?? const {});
    } on AppException catch (error) {
      if (error.isUnauthorized || error.kind == AppErrorKind.forbidden)
        return null;
      rethrow;
    }
  }

  /// Cierra la sesión en el backend (invalida la credencial en el servidor).
  Future<void> cerrarSesion() async {
    try {
      await _client.post<void>('/auth/logout');
    } on DioException {
      // Se limpia la sesión local de todas formas.
    } on AppException {
      // Idem: el logout local nunca debe fallar por el servidor.
    }
  }
}

final sesionRepositoryProvider = Provider<SesionRepository>(
  (ref) => SesionRepository(ref.watch(apiClientProvider)),
);
