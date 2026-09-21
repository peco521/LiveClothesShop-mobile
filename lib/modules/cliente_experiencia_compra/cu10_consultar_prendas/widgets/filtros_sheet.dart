import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/catalogo_repository.dart';
import '../models/producto.dart';
import '../providers/catalogo_provider.dart';

/// Hoja de filtros de CU10: modelo de polera (categoría), marca, temporada,
/// talla, rango de precio, solo disponibles y orden.
class FiltrosSheet extends ConsumerStatefulWidget {
  const FiltrosSheet({super.key});

  static Future<void> mostrar(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const FiltrosSheet(),
      );

  @override
  ConsumerState<FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends ConsumerState<FiltrosSheet> {
  late FiltrosCatalogo _borrador = ref.read(filtrosCatalogoProvider);
  late final TextEditingController _min = TextEditingController(
    text: _borrador.minPrecio?.toStringAsFixed(2) ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: _borrador.maxPrecio?.toStringAsFixed(2) ?? '',
  );

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _aplicar() {
    final min = double.tryParse(_min.text.replaceAll(',', '.'));
    final max = double.tryParse(_max.text.replaceAll(',', '.'));
    ref
        .read(filtrosCatalogoProvider.notifier)
        .aplicar(
          _borrador.copyWith(
            minPrecio: min,
            maxPrecio: max,
            limpiarPrecios: min == null && max == null,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final facetas = ref.watch(facetasCatalogoProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.gapLarge,
        right: AppTheme.gapLarge,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.gapLarge,
        top: AppTheme.gap,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filtrar poleras',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.gap),
            facetas.when(
              loading: () => const LoadingView(message: 'Cargando filtros…'),
              error: (error, _) => const Text(
                'No pudimos cargar los filtros disponibles.',
                style: TextStyle(color: AppColors.muted),
              ),
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _selector(
                    'Modelo de polera',
                    value.modelos,
                    _borrador.idCat,
                    (id) => setState(
                      () => _borrador = _borrador.copyWith(
                        idCat: id,
                        limpiarModelo: id == null,
                      ),
                    ),
                  ),
                  _selector(
                    'Marca',
                    value.marcas,
                    _borrador.idMarca,
                    (id) => setState(
                      () => _borrador = _borrador.copyWith(
                        idMarca: id,
                        limpiarMarca: id == null,
                      ),
                    ),
                  ),
                  _selector(
                    'Temporada',
                    value.temporadas,
                    _borrador.idTemp,
                    (id) => setState(
                      () => _borrador = _borrador.copyWith(
                        idTemp: id,
                        limpiarTemporada: id == null,
                      ),
                    ),
                  ),
                  _selector(
                    'Talla',
                    value.tallas,
                    _borrador.idTalla,
                    (id) => setState(
                      () => _borrador = _borrador.copyWith(
                        idTalla: id,
                        limpiarTalla: id == null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.gap),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio mínimo',
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.gap),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio máximo',
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo poleras disponibles'),
              value: _borrador.soloDisponibles,
              onChanged: (value) => setState(
                () => _borrador = _borrador.copyWith(soloDisponibles: value),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _borrador.sort,
              decoration: const InputDecoration(labelText: 'Orden'),
              items: const [
                DropdownMenuItem(
                  value: 'nombre_asc',
                  child: Text('Nombre A–Z'),
                ),
                DropdownMenuItem(
                  value: 'nombre_desc',
                  child: Text('Nombre Z–A'),
                ),
                DropdownMenuItem(
                  value: 'precio_asc',
                  child: Text('Menor precio'),
                ),
                DropdownMenuItem(
                  value: 'precio_desc',
                  child: Text('Mayor precio'),
                ),
              ],
              onChanged: (value) => setState(
                () =>
                    _borrador = _borrador.copyWith(sort: value ?? 'nombre_asc'),
              ),
            ),
            const SizedBox(height: AppTheme.gapLarge),
            ElevatedButton(
              onPressed: _aplicar,
              child: const Text('Aplicar filtros'),
            ),
            const SizedBox(height: AppTheme.gap),
            OutlinedButton(
              onPressed: () {
                ref.read(filtrosCatalogoProvider.notifier).limpiar();
                Navigator.of(context).pop();
              },
              child: const Text('Limpiar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selector(
    String label,
    List<FacetaItem> items,
    int? seleccionado,
    ValueChanged<int?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gap),
      child: DropdownButtonFormField<int?>(
        initialValue: items.any((item) => item.id == seleccionado)
            ? seleccionado
            : null,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
          for (final item in items)
            DropdownMenuItem<int?>(value: item.id, child: Text(item.nombre)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
