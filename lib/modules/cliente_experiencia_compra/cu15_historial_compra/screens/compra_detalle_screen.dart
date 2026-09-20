import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/historial_repository.dart';

/// CU15 Detalle de una compra del historial (solo lectura).
class CompraDetalleScreen extends ConsumerWidget {
  const CompraDetalleScreen({super.key, required this.nroVenta});

  static const String routePath = '/historial/:nro';

  final int nroVenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compra = ref.watch(compraHistorialDetalleProvider(nroVenta));
    return Scaffold(
      appBar: AppBar(title: Text('Compra #$nroVenta')),
      body: compra.when(
        loading: () => const LoadingView(message: 'Cargando el detalle…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () =>
                ref.invalidate(compraHistorialDetalleProvider(nroVenta)),
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
              Text(
                fechaHora(detalle.fechaHora),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              Text(
                '${detalle.sucursal.nombre} · ${detalle.sucursal.ciudad}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              if ((detalle.nit ?? '').isNotEmpty)
                Text(
                  'NIT ${detalle.nit}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              const SizedBox(height: AppTheme.gap),
              NoticeBanner(
                message:
                    '${etiquetaVenta(detalle.estado)} · ${etiquetaPago(detalle.estadoPago)}',
                success: detalle.estadoPago == 'aprobado',
              ),
              const SizedBox(height: AppTheme.gapLarge),
              Text('Productos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final item in detalle.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.producto),
                  subtitle: Text(
                    '${item.cantidad} × ${money(item.precioUnitario)} · SKU ${item.sku}',
                  ),
                  trailing: Text(money(item.subtotalBruto)),
                ),
              const Divider(),
              _importe('Bruto', detalle.brutoTotal),
              _importe('Descuento', -detalle.descAplicado),
              _importe('Total', detalle.total, destacado: true),
              if (detalle.pago != null) ...[
                const SizedBox(height: AppTheme.gapLarge),
                Text('Pago', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '${detalle.pago!.metodo} · ${etiquetaPago(detalle.pago!.estado)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                Text(
                  money(detalle.pago!.monto),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((detalle.pago!.referencia ?? '').isNotEmpty)
                  Text(
                    'Referencia: ${detalle.pago!.referencia}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
              const SizedBox(height: AppTheme.gapLarge),
              OutlinedButton(
                onPressed: () => context.go('/historial'),
                child: const Text('Volver a mis compras'),
              ),
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
