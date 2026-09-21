import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/historial_repository.dart';

/// CU15 Mis compras: lista de ventas con acceso a su detalle.
class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  static const String routePath = '/historial';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis compras'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(historialProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: historial.when(
        loading: () => const LoadingView(message: 'Cargando tus compras…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () => ref.invalidate(historialProvider),
          ),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Aún no tienes compras',
              message:
                  data.mensaje ?? 'Cuando compres una polera aparecerá aquí.',
              actionLabel: 'Ver catálogo',
              onAction: () => context.go('/catalogo'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.gapLarge),
            itemCount: data.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gap),
            itemBuilder: (context, index) {
              final compra = data.items[index];
              return Card(
                child: InkWell(
                  onTap: () => context.push('/historial/${compra.nroVenta}'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Compra #${compra.nroVenta}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              money(compra.monto),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fechaHora(compra.fechaHora),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          etiquetaPago(compra.estadoPago),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final producto in compra.productos)
                          Text(
                            '• ${producto.producto} × ${producto.cantidad}',
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
