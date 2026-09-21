import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/carrito_provider.dart';
import '../widgets/carrito_item.dart';

/// CU12 Carrito: productos, cantidades, subtotal y paso a CU13.
class CarritoScreen extends ConsumerStatefulWidget {
  const CarritoScreen({super.key});

  static const String routePath = '/carrito';

  @override
  ConsumerState<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends ConsumerState<CarritoScreen> {
  bool _ocupado = false;
  String? _aviso;
  bool _exito = false;

  Future<void> _ejecutar(Future<void> Function() accion, String ok) async {
    setState(() {
      _ocupado = true;
      _aviso = null;
      _exito = false;
    });
    try {
      await accion();
      _exito = true;
      _aviso = ok;
    } on AppException catch (error) {
      _aviso = error.message;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi carrito'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _ocupado
                ? null
                : () => ref.read(carritoProvider.notifier).refrescar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: carrito.when(
        loading: () => const LoadingView(message: 'Cargando tu carrito…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () => ref.read(carritoProvider.notifier).refrescar(),
          ),
        ),
        data: (carga) {
          if (carga.vacio) {
            return EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: 'Tu carrito está vacío',
              message:
                  'Agrega poleras del catálogo para continuar con tu compra.',
              actionLabel: 'Ver catálogo',
              onAction: () => context.go('/catalogo'),
            );
          }
          return Column(
            children: [
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.gap),
                  child: NoticeBanner(message: _aviso!, success: _exito),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.gapLarge),
                  itemCount: carga.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.gap),
                  itemBuilder: (context, index) {
                    final item = carga.items[index];
                    return CarritoItemCard(
                      item: item,
                      ocupado: _ocupado,
                      onCambiarCantidad: (cantidad) => _ejecutar(
                        () => ref
                            .read(carritoProvider.notifier)
                            .cambiarCantidad(
                              idDetalleCarro: item.idDetalleCarro,
                              cantidad: cantidad,
                            ),
                        'Cantidad actualizada.',
                      ),
                      onEliminar: () => _ejecutar(
                        () => ref
                            .read(carritoProvider.notifier)
                            .eliminar(item.idDetalleCarro),
                        'Se quitó la polera del carrito.',
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.gapLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${carga.cantidadItems} unidad(es)',
                            style: const TextStyle(color: Color(0xFF64695F)),
                          ),
                          const Spacer(),
                          Text(
                            money(carga.subtotal),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.gap),
                      ElevatedButton(
                        onPressed: _ocupado
                            ? null
                            : () => context.go('/checkout'),
                        child: const Text('Continuar compra'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
