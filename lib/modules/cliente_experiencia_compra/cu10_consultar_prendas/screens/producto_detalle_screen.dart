import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../cu12_carrito/providers/carrito_provider.dart';
import '../../cu16_realidad_aumentada/screens/probador_ra_screen.dart';
import '../../shared/widgets/producto_visual.dart';
import '../models/producto.dart';
import '../providers/catalogo_provider.dart';

/// CU10 Detalle de la polera: variantes (talla/color), disponibilidad y acceso a
/// las acciones normales del catálogo (CU12 carrito y CU11 reserva).
class ProductoDetalleScreen extends ConsumerStatefulWidget {
  const ProductoDetalleScreen({super.key, required this.idProd});

  static const String routePath = '/producto/:id';

  final String idProd;

  @override
  ConsumerState<ProductoDetalleScreen> createState() =>
      _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends ConsumerState<ProductoDetalleScreen> {
  String? _idVar;
  int _cantidad = 1;
  bool _agregando = false;

  VarianteDetalle? _variante(ProductoDetalle producto) {
    if (producto.variantes.isEmpty) return null;
    final seleccionada = _idVar;
    if (seleccionada != null) {
      for (final variante in producto.variantes) {
        if (variante.idVariante == seleccionada) return variante;
      }
    }
    return producto.variantes.firstWhere(
      (variante) => producto.disponibleEn(variante.idVariante),
      orElse: () => producto.variantes.first,
    );
  }

  void _elegir(String idVar) => setState(() {
    _idVar = idVar;
    _cantidad = 1;
  });

  void _avisar(String mensaje, {bool exito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: exito ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _agregarAlCarrito(String idVar) async {
    setState(() => _agregando = true);
    try {
      await ref
          .read(carritoProvider.notifier)
          .agregar(idVar: idVar, cantidad: _cantidad);
      if (mounted) _avisar('Agregamos la polera a tu carrito.', exito: true);
    } on AppException catch (error) {
      if (mounted) _avisar(error.message);
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(productoDetalleProvider(widget.idProd));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de polera')),
      body: detalle.when(
        loading: () => const LoadingView(message: 'Cargando polera…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () =>
                ref.invalidate(productoDetalleProvider(widget.idProd)),
          ),
        ),
        data: _contenido,
      ),
    );
  }

  String _etiquetaVariante(VarianteDetalle variante) {
    final colores = variante.colores
        .map((color) => color.descripcion)
        .join(' / ');
    return colores.isEmpty
        ? variante.talla.descripcion
        : '${variante.talla.descripcion} · $colores';
  }

  Widget _dato(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      '$etiqueta: $valor',
      style: const TextStyle(fontSize: 13, color: AppColors.muted),
    ),
  );

  Widget _contenido(ProductoDetalle producto) {
    final variante = _variante(producto);
    final stock = variante == null ? 0 : producto.stockDe(variante.idVariante);
    final disponible = variante != null && stock > 0;
    final promocion = producto.promocion;
    final primera = producto.variantes.isEmpty
        ? null
        : producto.variantes.first;
    final precio = variante?.precio ?? primera?.precio;
    final imagen = (variante ?? primera)?.imagen;
    final sucursales = variante == null
        ? const <DisponibilidadSucursal>[]
        : producto.sucursalesDe(variante.idVariante);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.gapLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: AspectRatio(
                aspectRatio: 1,
                child: ImagenProducto(
                  url: imagen,
                  descripcion: producto.descripcion,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          Text(
            producto.descripcion,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            producto.marca.nombre.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          _dato('Modelo de polera', producto.categoria.descripcion),
          _dato('Colección', producto.coleccion.descripcion),
          _dato('SKU', variante?.sku ?? '—'),
          const SizedBox(height: AppTheme.gap),
          PrecioProducto(
            precioMin: precio,
            precioMax: precio,
            tipoDescuento: promocion?.tipoDescuento,
            valorDescuento: promocion?.valorDescuento ?? 0,
          ),
          if (promocion != null)
            Text(
              'Promoción: ${promocion.nombre}',
              style: const TextStyle(fontSize: 12, color: AppColors.priceSale),
            ),
          const SizedBox(height: AppTheme.gapLarge),
          Text('Talla y color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (producto.variantes.isEmpty)
            const Text(
              'Sin variantes registradas.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in producto.variantes)
                  ChoiceChip(
                    label: Text(_etiquetaVariante(item)),
                    selected: item.idVariante == variante?.idVariante,
                    onSelected: (_) => _elegir(item.idVariante),
                  ),
              ],
            ),
          const SizedBox(height: AppTheme.gapLarge),
          Text(
            'Disponibilidad por sucursal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (sucursales.isEmpty)
            const Text(
              'Sin existencias registradas para esta variante.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final sucursal in sucursales)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storefront_outlined),
                title: Text('${sucursal.sucursal} · ${sucursal.ciudad}'),
                trailing: Text(
                  '${sucursal.cantDisp} disp.',
                  style: TextStyle(
                    color: sucursal.cantDisp > 0
                        ? AppColors.success
                        : AppColors.muted,
                  ),
                ),
              ),
          const SizedBox(height: AppTheme.gap),
          Row(
            children: [
              const Text('Cantidad'),
              const Spacer(),
              IconButton(
                onPressed: _cantidad > 1
                    ? () => setState(() => _cantidad -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_cantidad',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _cantidad < stock
                    ? () => setState(() => _cantidad += 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.gap),
          ElevatedButton(
            onPressed: disponible && !_agregando
                ? () => _agregarAlCarrito(variante.idVariante)
                : null,
            child: Text(_agregando ? 'Agregando…' : 'Agregar al carrito'),
          ),
          const SizedBox(height: AppTheme.gap),
          // CU16: probador virtual con la variante/color y la talla elegidas.
          // Es una acción secundaria destacada: no compite con la compra.
          if (variante != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
              onPressed: () => context.push(
                ProbadorRaScreen.ruta(
                  idProd: producto.idProd,
                  idVar: variante.idVariante,
                  talla: variante.talla.descripcion,
                  cantidad: _cantidad,
                ),
              ),
              icon: const Icon(Icons.camera_front_outlined),
              label: const Text('Probar con realidad aumentada'),
            ),
          const SizedBox(height: AppTheme.gap),
          OutlinedButton(
            onPressed: disponible
                ? () => context.push(
                    '/reserva/nueva?idVar=${variante.idVariante}&cantidad=$_cantidad',
                  )
                : null,
            child: const Text('Reservar en sucursal'),
          ),
          if (!disponible)
            const Padding(
              padding: EdgeInsets.only(top: AppTheme.gap),
              child: Text(
                'Esta variante no tiene existencias disponibles.',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}
