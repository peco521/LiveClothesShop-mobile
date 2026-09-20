import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modules/cliente_experiencia_compra/cu01_registro_cliente/screens/registro_screen.dart';
import '../../modules/cliente_experiencia_compra/cu02_iniciar_sesion/screens/login_screen.dart';
import '../../modules/cliente_experiencia_compra/cu04_recuperar_contrasena/screens/recuperar_screen.dart';
import '../../modules/cliente_experiencia_compra/cu04_recuperar_contrasena/screens/restablecer_screen.dart';
import '../../modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/catalogo_screen.dart';
import '../../modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/producto_detalle_screen.dart';
import '../../modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/nueva_reserva_screen.dart';
import '../../modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/reserva_detalle_screen.dart';
import '../../modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/reservas_screen.dart';
import '../../modules/cliente_experiencia_compra/cu12_carrito/screens/carrito_screen.dart';
import '../../modules/cliente_experiencia_compra/cu13_compra_digital/screens/checkout_screen.dart';
import '../../modules/cliente_experiencia_compra/cu13_compra_digital/screens/venta_detalle_screen.dart';
import '../../modules/cliente_experiencia_compra/cu14_pago_electronico/screens/pago_screen.dart';
import '../../modules/cliente_experiencia_compra/cu15_historial_compra/screens/compra_detalle_screen.dart';
import '../../modules/cliente_experiencia_compra/cu15_historial_compra/screens/historial_screen.dart';
import '../../modules/cliente_experiencia_compra/cu17_recomendaciones/screens/recomendaciones_screen.dart';
import '../../modules/cliente_experiencia_compra/shared/providers/sesion_provider.dart';
import '../../modules/cliente_experiencia_compra/shared/screens/cuenta_screen.dart';
import 'app_shell.dart';

/// Rutas públicas: accesibles sin sesión (CU01, CU02, CU04).
const rutasPublicas = {
  '/login',
  '/registro',
  '/recuperar',
  '/restablecer',
  '/cargando',
};

/// Router central: cada ruta carga la pantalla de su caso de uso y las rutas
/// privadas quedan protegidas por sesión (también ante deep links).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresco = ValueNotifier<int>(0);
  // Cualquier cambio de sesión (login, logout, expiración) reevalúa la guarda.
  ref.listen<AsyncValue<Object?>>(sesionProvider, (_, __) => refresco.value++);
  final router = GoRouter(
    initialLocation: '/catalogo',
    refreshListenable: refresco,
    redirect: (context, state) {
      final sesion = ref.read(sesionProvider);
      final ubicacion = state.matchedLocation;
      final publica = rutasPublicas.contains(ubicacion);
      if (sesion.isLoading)
        return ubicacion == '/cargando' ? null : '/cargando';
      if (sesion.valueOrNull == null) return publica ? null : '/login';
      if (publica) return '/catalogo';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (_, __) => const RegistroScreen()),
      GoRoute(path: '/recuperar', builder: (_, __) => const RecuperarScreen()),
      GoRoute(
        path: '/restablecer',
        builder: (_, __) => const RestablecerScreen(),
      ),
      GoRoute(path: '/cargando', builder: (_, __) => const _PantallaCarga()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catalogo',
                builder: (_, __) => const CatalogoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recomendaciones',
                builder: (_, __) => const RecomendacionesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reservas',
                builder: (_, __) => const ReservasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/carrito',
                builder: (_, __) => const CarritoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cuenta',
                builder: (_, __) => const CuentaScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/producto/:id',
        builder: (_, state) =>
            ProductoDetalleScreen(idProd: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/reserva/nueva',
        builder: (_, state) => NuevaReservaScreen(
          idVar: state.uri.queryParameters['idVar'] ?? '',
          cantidad:
              int.tryParse(state.uri.queryParameters['cantidad'] ?? '') ?? 1,
        ),
      ),
      GoRoute(
        path: '/reservas/:nro',
        builder: (_, state) => ReservaDetalleScreen(
          nroReserva: int.tryParse(state.pathParameters['nro'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(
        path: '/compra/:nro',
        builder: (_, state) => VentaDetalleScreen(
          nroVenta: int.tryParse(state.pathParameters['nro'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/pago',
        builder: (_, state) => PagoScreen(
          nroVenta:
              int.tryParse(state.uri.queryParameters['nroVenta'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/historial', builder: (_, __) => const HistorialScreen()),
      GoRoute(
        path: '/historial/:nro',
        builder: (_, state) => CompraDetalleScreen(
          nroVenta: int.tryParse(state.pathParameters['nro'] ?? '') ?? 0,
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresco.dispose();
  });
  return router;
});

/// Pantalla intermedia mientras se restaura la sesión desde la cookie.
class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando tu sesión…'),
          ],
        ),
      ),
    );
  }
}
