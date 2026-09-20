import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../../cu02_iniciar_sesion/data/sesion_repository.dart';
import '../models/sesion.dart';

/// Estado global de sesión del cliente.
///
/// Se comparte entre CU01/CU02/CU04 y todos los CU que exigen sesión (CU11-CU15,
/// CU17): cada provider de caso de uso que observa [sesionProvider] se refresca
/// automáticamente al iniciar o cerrar sesión.
final sesionProvider = AsyncNotifierProvider<SesionController, Sesion?>(
  SesionController.new,
);

class SesionController extends AsyncNotifier<Sesion?> {
  @override
  Future<Sesion?> build() async {
    // Si el backend responde 401 en cualquier llamada, la sesión local se cierra
    // y el router redirige al login.
    final subscription = ref.watch(apiClientProvider).onUnauthorized.listen((
      _,
    ) {
      if (state.valueOrNull != null) state = const AsyncData(null);
    });
    ref.onDispose(subscription.cancel);
    return ref.read(sesionRepositoryProvider).sesionActual();
  }

  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(sesionRepositoryProvider)
          .iniciarSesion(correo: correo, contrasena: contrasena),
    );
  }

  /// CU01 la usa tras registrarse: el backend ya dejó la cookie de sesión activa.
  void establecer(Sesion sesion) => state = AsyncData(sesion);

  Future<void> cerrarSesion() async {
    await ref.read(sesionRepositoryProvider).cerrarSesion();
    await ref.read(apiClientProvider).clearCookies();
    state = const AsyncData(null);
  }
}
