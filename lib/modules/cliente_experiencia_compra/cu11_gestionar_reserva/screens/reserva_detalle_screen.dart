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
import '../providers/reservas_provider.dart';

/// CU11 Detalle de una reserva, con la cancelación soportada por el backend.
class ReservaDetalleScreen extends ConsumerStatefulWidget {
  const ReservaDetalleScreen({super.key, required this.nroReserva});

  static const String routePath = '/reservas/:nro';

  final int nroReserva;

  @override
  ConsumerState<ReservaDetalleScreen> createState() =>
      _ReservaDetalleScreenState();
}

class _ReservaDetalleScreenState extends ConsumerState<ReservaDetalleScreen> {
  bool _ocupado = false;
  String? _aviso;

  Future<void> _cancelar() async {
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      await ref.read(reservasProvider.notifier).cancelar(widget.nroReserva);
      if (mounted) setState(() => _aviso = 'La reserva fue cancelada.');
    } on AppException catch (error) {
      setState(() => _aviso = error.message);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reserva = ref.watch(reservaDetalleProvider(widget.nroReserva));
    return Scaffold(
      appBar: AppBar(title: Text('Reserva #${widget.nroReserva}')),
      body: reserva.when(
        loading: () => const LoadingView(message: 'Cargando la reserva…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () =>
                ref.invalidate(reservaDetalleProvider(widget.nroReserva)),
          ),
        ),
        data: (detalle) {
          if (detalle.items.isEmpty) {
            return const EmptyView(
              title: 'Sin prendas',
              message: 'Esta reserva no tiene prendas registradas.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppTheme.gapLarge),
            children: [
              if (_aviso != null) ...[
                NoticeBanner(message: _aviso!),
                const SizedBox(height: AppTheme.gap),
              ],
              NoticeBanner(
                message: etiquetaReserva(detalle.estado),
                success:
                    detalle.estado == 'confirmada' ||
                    detalle.estado == 'atendida',
              ),
              const SizedBox(height: AppTheme.gap),
              Text(
                '${fecha(detalle.fechaReserva)} · ${hora(detalle.horaAtencion)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${detalle.sucursal.nombre} · ${detalle.sucursal.ciudad}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppTheme.gapLarge),
              Text(
                'Prendas reservadas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (final item in detalle.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.producto),
                  subtitle: Text(
                    [
                      if ((item.talla ?? '').isNotEmpty) 'Talla ${item.talla}',
                      if ((item.categoria ?? '').isNotEmpty)
                        'Modelo ${item.categoria}',
                      if (item.colores.isNotEmpty) item.colores.join(' / '),
                      'SKU ${item.sku}',
                    ].join(' · '),
                  ),
                  trailing: Text('× ${item.cantidad}'),
                ),
              const Divider(),
              Text(
                'Total: ${detalle.totalUnidades} unidad(es)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.gapLarge),
              if (detalle.puedeCancelarse)
                OutlinedButton(
                  onPressed: _ocupado ? null : _cancelar,
                  child: Text(_ocupado ? 'Cancelando…' : 'Cancelar reserva'),
                ),
              const SizedBox(height: AppTheme.gap),
              OutlinedButton(
                onPressed: () => context.go('/reservas'),
                child: const Text('Volver a mis reservas'),
              ),
            ],
          );
        },
      ),
    );
  }
}
