import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../models/producto_resumen.dart';
import 'producto_visual.dart';

/// Tarjeta de polera compartida por CU10 (catálogo) y CU17 (recomendaciones).
///
/// CU17 solo añade los motivos de la recomendación; la tarjeta es la misma para
/// que la experiencia se sienta integrada.
class ProductoCard extends StatelessWidget {
  const ProductoCard({
    super.key,
    required this.producto,
    required this.onTap,
    this.razones = const [],
    this.desdeTexto = false,
  });

  final ProductoResumen producto;
  final VoidCallback onTap;

  /// Motivos que envía el backend de CU17 ("razones"). Vacío en CU10.
  final List<String> razones;
  final bool desdeTexto;

  @override
  Widget build(BuildContext context) {
    final promo = producto.promocion;
    final vista = cotizarPrecio(
      precio: producto.precioMin,
      tipoDescuento: promo?.tipoDescuento,
      valorDescuento: promo?.valorDescuento ?? 0,
    );
    return Semantics(
      button: true,
      label:
          '${producto.descripcion}, ${producto.marca.nombre}, '
          '${producto.precioMin == null ? 'precio a consultar' : money(vista.total)}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Altura acotada por la grilla: la vista nunca lanza overflow; si el
          // texto es más alto de lo previsto se recorta en lugar de romper.
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ImagenProducto(
                          url: producto.imagen,
                          descripcion: producto.descripcion,
                        ),
                      ),
                      if (vista.enOferta)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.priceSale,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '−${vista.porcentaje}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    producto.marca.nombre.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    producto.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Modelo: ${producto.categoria.descripcion}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PrecioProducto(
                    precioMin: producto.precioMin,
                    precioMax: producto.precioMax,
                    tipoDescuento: promo?.tipoDescuento,
                    valorDescuento: promo?.valorDescuento ?? 0,
                    desdeTexto: desdeTexto,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    producto.disponible ? 'Disponible' : 'Agotado',
                    style: TextStyle(
                      fontSize: 12,
                      color: producto.disponible
                          ? AppColors.success
                          : AppColors.muted,
                    ),
                  ),
                  if (razones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final razon in razones)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              razon,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
