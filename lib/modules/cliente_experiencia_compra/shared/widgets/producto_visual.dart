import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// Estimación visual del descuento vigente (igual criterio que la web Angular).
///
/// Solo se usa para mostrar precios; el total real del pedido siempre lo calcula
/// el backend (CU12/CU13), que es la fuente de verdad.
class PrecioVista {
  const PrecioVista({
    required this.base,
    required this.descuento,
    required this.porcentaje,
  });

  final double base;
  final double descuento;
  final double porcentaje;

  double get total => (base - descuento).clamp(0, double.infinity);
  bool get enOferta => descuento > 0;
}

PrecioVista cotizarPrecio({
  required double? precio,
  required String? tipoDescuento,
  required double valorDescuento,
}) {
  final base = precio ?? 0;
  if (base <= 0 || tipoDescuento == null) {
    return PrecioVista(base: base, descuento: 0, porcentaje: 0);
  }
  final bruto = tipoDescuento == 'porcentaje'
      ? base * valorDescuento / 100
      : valorDescuento;
  final descuento = bruto.clamp(0, base).toDouble();
  final double porcentaje = base > 0
      ? (descuento * 1000 / base).round() / 10
      : 0;
  return PrecioVista(base: base, descuento: descuento, porcentaje: porcentaje);
}

/// Imagen remota de una polera (caché en disco) con placeholder de carga y de
/// error: una URL rota nunca rompe el layout.
class ImagenProducto extends StatelessWidget {
  const ImagenProducto({
    super.key,
    required this.url,
    required this.descripcion,
    this.radius = 10,
  });

  final String? url;
  final String descripcion;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget placeholder(BuildContext context, String url) => const ColoredBox(
      color: AppColors.surfaceSoft,
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
    Widget error(BuildContext context, String url, Object exception) =>
        const ColoredBox(
          color: AppColors.surfaceSoft,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.muted,
            ),
          ),
        );
    final value = url?.trim() ?? '';
    return Semantics(
      image: true,
      label: value.isEmpty
          ? 'Sin imagen de $descripcion'
          : 'Imagen de $descripcion',
      child: ClipRRect(
        borderRadius: shape,
        child: value.isEmpty
            ? error(context, value, StateError('sin imagen'))
            : CachedNetworkImage(
                imageUrl: value,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: placeholder,
                errorWidget: error,
              ),
      ),
    );
  }
}

/// Texto de precio con etiqueta de oferta (reutilizado por CU10 y CU17).
class PrecioProducto extends StatelessWidget {
  const PrecioProducto({
    super.key,
    required this.precioMin,
    required this.precioMax,
    required this.tipoDescuento,
    required this.valorDescuento,
    this.desdeTexto = false,
  });

  final double? precioMin;
  final double? precioMax;
  final String? tipoDescuento;
  final double valorDescuento;
  final bool desdeTexto;

  @override
  Widget build(BuildContext context) {
    if (precioMin == null) {
      return const Text(
        'Precio a consultar',
        style: TextStyle(color: AppColors.muted),
      );
    }
    final vista = cotizarPrecio(
      precio: precioMin,
      tipoDescuento: tipoDescuento,
      valorDescuento: valorDescuento,
    );
    final rango = (precioMax ?? precioMin) != precioMin;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(
          '${rango && desdeTexto ? 'Desde ' : ''}${money(vista.total)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: vista.enOferta ? AppColors.priceSale : AppColors.ink,
          ),
        ),
        if (vista.enOferta)
          Text(
            money(vista.base),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}
