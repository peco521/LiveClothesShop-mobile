import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_view.dart';
import '../models/recomendacion.dart';
import '../providers/recomendaciones_provider.dart';
import '../widgets/recomendacion_card.dart';

/// CU17 Recomendaciones para ti.
///
/// Los estados cubren: carga, resultado personalizado, fallback general,
/// catálogo sin recomendaciones y error (siempre con opción de reintentar).
class RecomendacionesScreen extends ConsumerWidget {
  const RecomendacionesScreen({super.key});

  static const String routePath = '/recomendaciones';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recomendaciones = ref.watch(recomendacionesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomendaciones para ti'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(recomendacionesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: recomendaciones.when(
        loading: () =>
            const LoadingView(message: 'Buscando recomendaciones para ti…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () => ref.invalidate(recomendacionesProvider),
          ),
        ),
        data: (respuesta) => respuesta.items.isEmpty
            ? EmptyView(
                icon: Icons.auto_awesome_outlined,
                title: 'No hay recomendaciones disponibles en este momento.',
                message:
                    'Vuelve al catálogo y explora las poleras disponibles.',
                actionLabel: 'Ver catálogo',
                onAction: () => context.go('/catalogo'),
              )
            : _resultado(context, respuesta),
      ),
    );
  }

  Widget _resultado(BuildContext context, RecomendacionesRespuesta respuesta) {
    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gapLarge,
              AppTheme.gap,
              AppTheme.gapLarge,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mensaje calculado por el backend (personalizado o de fallback).
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      respuesta.mensaje,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    respuesta.esPersonalizada
                        ? 'Poleras elegidas según tus interacciones.'
                        : 'Poleras populares del catálogo.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppTheme.gap),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.gapLarge),
            // Responsive: 1 columna en pantallas angostas, más si hay ancho.
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                mainAxisSpacing: AppTheme.gap,
                crossAxisSpacing: AppTheme.gap,
                childAspectRatio: 0.46,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final recomendacion = respuesta.items[index];
                return RecomendacionCard(
                  recomendacion: recomendacion,
                  onTap: () => context.push(
                    '/producto/${recomendacion.producto.idProd}',
                  ),
                );
              }, childCount: respuesta.items.length),
            ),
          ),
        ],
      ),
    );
  }
}
