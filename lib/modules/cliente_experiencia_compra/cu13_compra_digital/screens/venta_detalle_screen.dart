import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/compra_provider.dart';

/// CU13 Detalle de una venta propia, con acceso al pago (CU14) y cancelación.
class VentaDetalleScreen extends ConsumerStatefulWidget {
  const VentaDetalleScreen({super.key, required this.nroVenta});

  static const String routePath = '/compra/:nro';

  final int nroVenta;

  @override
  ConsumerState<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends ConsumerState<VentaDetalleScreen> {
  bool _ocupado = false;
  String? _aviso;

  Future<void> _cancelar() async {
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      await ref.read(checkoutProvider.notifier).cancelar(widget.nroVenta);
      ref.invalidate(ventaDetalleProvider(widget.nroVenta));
      if (mounted) context.go('/carrito');
    } on AppException catch (error) {
      setState(() => _aviso = error.message);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = ref.watch(ventaDetalleProvider(widget.nroVenta));
    return Scaffold(
      appBar: AppBar(title: Text('Compra #${widget.nroVenta}')),
      body: venta.when(
        loading: () => const LoadingView(message: 'Cargando la compra…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () =>
                ref.invalidate(ventaDetalleProvider(widget.nroVenta)),
          ),
        ),
        data: (detalle) {
          if (detalle.items.isEmpty) {
            return const EmptyView(
              title: 'Sin productos',
              message: 'Esta compra no tiene productos registrados.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppTheme.gapLarge),
            children: [
              if (_aviso != null) ...[
                NoticeBanner(message: _aviso!),
                const SizedBox(height: AppTheme.gap),
              ],
              Text(
                '${fechaHora(detalle.fechaHora)} · ${etiquetaVenta(detalle.estado)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppTheme.gap),
              for (final item in detalle.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.producto),
                  subtitle: Text(
                    '${item.cantidad} × ${money(item.precioUnitario)}',
                  ),
                  trailing: Text(money(item.subtotalBruto)),
                ),
              const Divider(),
              _importe('Bruto', detalle.brutoTotal),
              _importe('Descuento', -detalle.descAplicado),
              _importe('Total', detalle.total, destacado: true),
              const SizedBox(height: AppTheme.gapLarge),
              if (detalle.estado == 'registrada')
                ElevatedButton(
                  onPressed: () =>
                      context.go('/pago?nroVenta=${detalle.nroVenta}'),
                  child: const Text('Ir a pagar'),
                ),
              if (detalle.estado == 'registrada') ...[
                const SizedBox(height: AppTheme.gap),
                OutlinedButton(
                  onPressed: _ocupado ? null : _cancelar,
                  child: Text(_ocupado ? 'Cancelando…' : 'Cancelar compra'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _importe(String etiqueta, double valor, {bool destacado = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              etiqueta,
              style: TextStyle(fontWeight: destacado ? FontWeight.w600 : null),
            ),
            const Spacer(),
            Text(
              money(valor),
              style: TextStyle(fontWeight: destacado ? FontWeight.w700 : null),
            ),
          ],
        ),
      );
}
