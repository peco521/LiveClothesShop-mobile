import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/offline_sync.dart';
import 'core/session.dart';
import 'modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/catalogo_screen.dart';
import 'modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/mis_reservas_screen.dart';
import 'modules/cliente_experiencia_compra/cu12_carrito/screens/carrito_screen.dart';
import 'modules/cliente_experiencia_compra/cu13_compra_digital/screens/checkout_screen.dart';
import 'modules/cliente_experiencia_compra/cu14_pago_electronico/screens/pago_screen.dart';
import 'modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/nueva_reserva_screen.dart';
import 'modules/seguridad_accesos/login_screen.dart';
import 'modules/ventas_reportes/caja_screen.dart';
import 'modules/cliente_experiencia_compra/cu15_historial_compra/historial_screen.dart';
import 'modules/cliente_experiencia_compra/cu10_consultar_prendas/models/catalogo.dart';
import 'modules/cliente_experiencia_compra/cu23_vestidor_virtual/screens/vestidor_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineBackgroundWorker.initialize();
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
          '/caja': (_) => const CajaScreen(),
          '/tienda': (_) => const _TiendaGuard(child: CatalogoScreen()),
          '/tienda/reservas': (_) => const _TiendaGuard(child: MisReservasScreen()),
          '/tienda/carrito': (_) => const _TiendaGuard(child: CarritoScreen()),
          '/tienda/historial-compras': (_) => const _TiendaGuard(child: HistorialScreen()),
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
          if (settings.name == '/tienda/vestidor') {
            final args = settings.arguments as Map<String, dynamic>?;
            final prod = args?['producto'] as ProductoDetalle?;
            final varSel = args?['variante'] as VarianteDetalle?;
            if (prod != null) {
              return MaterialPageRoute(
                builder: (_) => _TiendaGuard(
                  child: VestidorScreen(
                    producto: prod,
                    varianteInicial: varSel,
                  ),
                ),
              );
            }
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
    if (session.isAuthenticated && session.user?.isCashier == true) return const CajaScreen();
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
    if (session.user?.tipo != 'C') return const Scaffold(body:Center(child:Text('Esta tienda requiere una cuenta de cliente. Usa el acceso de caja para cajeros.')));
      return Column(children: [
      _SyncStatus(session: session),
      Expanded(child: child),
    ]);
  }
}

class _SyncStatus extends StatefulWidget {
  final SessionState session;
  const _SyncStatus({required this.session});

  @override
  State<_SyncStatus> createState() => _SyncStatusState();
}

class _SyncStatusState extends State<_SyncStatus> {
  Future<void> _sync() async {
    await widget.session.sync.flush();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: widget.session.sync.list(),
    builder: (context, snapshot) {
      final operations = snapshot.data ?? const [];
      final pending = operations.where((item) => item.state.name == 'pending' || item.state.name == 'retryPending').length;
      final conflicts = operations.where((item) => item.state.name == 'conflict' || item.state.name == 'rejected').length;
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(child: Text(snapshot.hasError || widget.session.sync.persistenceError != null
              ? 'Cola local no disponible. No borres los datos de la aplicación; reintenta.'
              : '${widget.session.restoredOffline ? 'Sin conexión · ' : ''}Empresa ${widget.session.user?.empresa ?? ''} · '
                '$pending operaciones pendientes · $conflicts para revisar', maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton(onPressed: pending == 0 && !snapshot.hasError && widget.session.sync.persistenceError == null
              ? null : _sync, child: const Text('Sincronizar')),
          ]),
        ),
      );
    },
  );
}
