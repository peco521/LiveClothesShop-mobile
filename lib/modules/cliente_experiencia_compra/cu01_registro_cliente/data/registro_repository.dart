import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../../shared/models/sesion.dart';

/// CU01 Registro de cliente (`POST /api/auth/registro`).
///
/// El backend crea la cuenta y deja la sesión iniciada con la misma cookie que
/// el login, por eso devuelve también la sesión para que la app la adopte.
class RegistroRepository {
  const RegistroRepository(this._client);

  final ApiClient _client;

  Future<({Sesion sesion, String mensaje})> registrar(
    Map<String, dynamic> datos,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/registro',
      body: datos,
    );
    final data = response.data ?? const <String, dynamic>{};
    final sesion =
        (data['sesion'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return (
      sesion: Sesion.fromJson(sesion),
      mensaje:
          data['mensaje']?.toString() ?? 'Cliente registrado correctamente',
    );
  }
}

final registroRepositoryProvider = Provider<RegistroRepository>(
  (ref) => RegistroRepository(ref.watch(apiClientProvider)),
);
