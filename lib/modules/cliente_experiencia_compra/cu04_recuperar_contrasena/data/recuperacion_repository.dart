import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';

/// CU04 Recuperación de contraseña (envío por Gmail desde el backend).
class RecuperacionRepository {
  const RecuperacionRepository(this._client);

  final ApiClient _client;

  /// Solicita el enlace de recuperación. El backend responde 202 sin revelar si
  /// el correo existe.
  Future<void> solicitar(String correo) async {
    await _client.post<void>(
      '/auth/recuperar-contrasena',
      body: {'correo': correo.trim()},
    );
  }

  /// Restablece la contraseña con el token recibido por correo.
  Future<void> restablecer({
    required String token,
    required String nuevaContrasena,
  }) async {
    await _client.post<void>(
      '/auth/restablecer-contrasena',
      body: {'token': token.trim(), 'nueva_contrasena': nuevaContrasena},
    );
  }
}

final recuperacionRepositoryProvider = Provider<RecuperacionRepository>(
  (ref) => RecuperacionRepository(ref.watch(apiClientProvider)),
);
