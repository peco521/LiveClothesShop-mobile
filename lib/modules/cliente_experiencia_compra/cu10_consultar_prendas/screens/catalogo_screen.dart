import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../shared/widgets/producto_card.dart';
import '../data/catalogo_repository.dart';
import '../providers/catalogo_provider.dart';
import '../widgets/filtros_sheet.dart';

/// CU10 Inicio: catálogo de poleras con buscador, filtros y paginación.
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  static const String routePath = '/catalogo';

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  late final TextEditingController _busqueda = TextEditingController(
    text: ref.read(filtrosCatalogoProvider).q,
  );

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(filtrosCatalogoProvider);
    final catalogo = ref.watch(catalogoProvider);
    final activos = [
      if (filtros.idCat != null) 'Modelo',
      if (filtros.idMarca != null) 'Marca',
      if (filtros.idTemp != null) 'Temporada',
      if (filtros.idTalla != null) 'Talla',
      if (filtros.minPrecio != null || filtros.maxPrecio != null) 'Precio',
      if (filtros.soloDisponibles) 'Disponibles',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de poleras'),
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            onPressed: () => FiltrosSheet.mostrar(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gapLarge,
              AppTheme.gap,
              AppTheme.gapLarge,
              4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _busqueda,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Buscar poleras, marcas o modelos',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (value) => ref
                        .read(filtrosCatalogoProvider.notifier)
                        .buscar(value),
                  ),
                ),
                const SizedBox(width: AppTheme.gap),
                IconButton.filled(
                  tooltip: 'Buscar',
                  onPressed: () => ref
                      .read(filtrosCatalogoProvider.notifier)
                      .buscar(_busqueda.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          if (activos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.gapLarge,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros activos: ${activos.join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _busqueda.clear();
                      ref.read(filtrosCatalogoProvider.notifier).limpiar();
                    },
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: catalogo.when(
              loading: () => const LoadingView(message: 'Cargando poleras…'),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(AppTheme.gapLarge),
                child: ErrorView(
                  message: mensajeDeError(error),
                  onRetry: () =>
                      ref.read(catalogoProvider.notifier).refrescar(),
                ),
              ),
              data: (page) => page.items.isEmpty
                  ? const EmptyView(
                      icon: Icons.search_off,
                      title: 'Sin resultados',
                      message: 'No hay poleras para los filtros aplicados. Prueba otra búsqueda.',
                    )
                  : _grid(page),
            ),
          ),
          catalogo.maybeWhen(
            data: (page) => _paginacion(page),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _grid(ProductosCatalogo page) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.all(AppTheme.gapLarge),
        // Responsive: 1 columna en pantallas angostas y más columnas si hay ancho.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          mainAxisSpacing: AppTheme.gap,
          crossAxisSpacing: AppTheme.gap,
          childAspectRatio: 0.55,
        ),
        itemCount: page.items.length,
        itemBuilder: (context, index) {
          final producto = page.items[index];
          return ProductoCard(
            producto: producto,
            desdeTexto: true,
            onTap: () => context.push('/producto/${producto.idProd}'),
          );
        },
      ),
    );
  }

  Widget _paginacion(ProductosCatalogo page) {
    final hayAnterior = page.offset > 0;
    final haySiguiente = page.offset + page.limit < page.total;
    if (!hayAnterior && !haySiguiente) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.gap),
        child: Text(
          '${page.total} poleras',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gapLarge,
        vertical: AppTheme.gap,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: hayAnterior
                  ? () => ref
                        .read(filtrosCatalogoProvider.notifier)
                        .pagina(page.offset - page.limit)
                  : null,
              child: const Text('Anterior'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gap),
            child: Text(
              '${page.offset + 1}–${page.offset + page.items.length} de ${page.total}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: haySiguiente
                  ? () => ref
                        .read(filtrosCatalogoProvider.notifier)
                        .pagina(page.offset + page.limit)
                  : null,
              child: const Text('Siguiente'),
            ),
          ),
        ],
      ),
    );
  }
}
