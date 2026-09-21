import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/reservas_provider.dart';
import '../widgets/reserva_card.dart';

/// CU11 Mis reservas: lista de reservas propias con sus acciones.
class ReservasScreen extends ConsumerWidget {
  const ReservasScreen({super.key});

  static const String routePath = '/reservas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservas = ref.watch(reservasProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.read(reservasProvider.notifier).refrescar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: reservas.when(
        loading: () => const LoadingView(message: 'Cargando tus reservas…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () => ref.read(reservasProvider.notifier).refrescar(),
          ),
        ),
        data: (data) => data.items.isEmpty
            ? EmptyView(
                icon: Icons.event_available_outlined,
                title: 'Aún no tienes reservas',
                message: 'Reserva una polera desde su detalle y recógela en tu sucursal.',
                actionLabel: 'Ver catálogo',
                onAction: () => context.go('/catalogo'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.gapLarge),
                itemCount: data.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.gap),
                itemBuilder: (context, index) {
                  final reserva = data.items[index];
                  return ReservaCard(
                    reserva: reserva,
                    onTap: () =>
                        context.push('/reservas/${reserva.nroReserva}'),
                  );
                },
              ),
      ),
    );
  }
}
