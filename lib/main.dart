import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/session.dart';
import 'modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/catalogo_screen.dart';
import 'modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/mis_reservas_screen.dart';
import 'modules/cliente_experiencia_compra/cu12_carrito/screens/carrito_screen.dart';
import 'modules/cliente_experiencia_compra/cu13_compra_digital/screens/checkout_screen.dart';
import 'modules/cliente_experiencia_compra/cu14_pago_electronico/screens/pago_screen.dart';
import 'modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/nueva_reserva_screen.dart';
import 'modules/seguridad_accesos/login_screen.dart';

void main() {
  runApp(const LiveClothesShopApp());
}

class LiveClothesShopApp extends StatelessWidget {
  const LiveClothesShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionState()..restore(),
      child: MaterialApp(
        title: 'LiveClothesShop',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/tienda': (_) => const _TiendaGuard(child: CatalogoScreen()),
          '/tienda/reservas': (_) => const _TiendaGuard(child: MisReservasScreen()),
          '/tienda/carrito': (_) => const _TiendaGuard(child: CarritoScreen()),
          '/tienda/finalizar-compra': (_) => const _TiendaGuard(child: CheckoutScreen()),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/tienda/pago') {
            final args = settings.arguments as Map<String, dynamic>?;
            final nro = (args?['nroVenta'] as num?)?.toInt() ?? 0;
            return MaterialPageRoute(
              builder: (_) => _TiendaGuard(child: PagoScreen(nroVenta: nro)),
            );
          }
          if (settings.name == '/tienda/reservas/nueva') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => _TiendaGuard(
                child: NuevaReservaScreen(
                  idVarInicial: args?['idVar'] as String?,
                  cantidadInicial: (args?['cantidad'] as num?)?.toInt() ?? 1,
                ),
              ),
            );
          }
          return null;
        },
        home: const AuthGate(),
      ),
    );
  }
}

/// Puerta de autenticación: restaura la sesión y dirige a tienda o login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    if (session.status == SessionStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.isAuthenticated) return const _TiendaGuard(child: CatalogoScreen());
    return const LoginScreen();
  }
}

/// Guardia de tienda: solo clientes autenticados (el backend valida tipo='C').
class _TiendaGuard extends StatelessWidget {
  final Widget child;

  const _TiendaGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    if (!session.isAuthenticated) return const LoginScreen();
    return child;
  }
}
