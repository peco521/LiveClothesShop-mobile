import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../shared/widgets/producto_visual.dart';
import '../models/carrito.dart';

/// Fila de un producto del carrito (CU12) con controles de cantidad.
class CarritoItemCard extends StatelessWidget {
  const CarritoItemCard({
    super.key,
    required this.item,
    required this.ocupado,
    required this.onCambiarCantidad,
    required this.onEliminar,
  });

  final CarritoItem item;
  final bool ocupado;
  final ValueChanged<int> onCambiarCantidad;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final colores = item.colores.isEmpty
        ? ''
        : ' · ${item.colores.join(' / ')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: ImagenProducto(
                url: item.imagen,
                descripcion: item.producto,
              ),
            ),
            const SizedBox(width: AppTheme.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.producto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Talla ${item.talla.descripcion}$colores',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    'SKU ${item.sku}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PrecioProducto(
                    precioMin: item.precio,
                    precioMax: item.precio,
                    tipoDescuento: item.promocion?.tipoDescuento,
                    valorDescuento: item.promocion?.valorDescuento ?? 0,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal ${money(item.subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (!item.disponible)
                    Text(
                      'Solo quedan ${item.cantidadDisponible} unidades disponibles',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Quitar una unidad',
                        onPressed: ocupado || item.cantidad <= 1
                            ? null
                            : () => onCambiarCantidad(item.cantidad - 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${item.cantidad}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        tooltip: 'Agregar una unidad',
                        onPressed: ocupado
                            ? null
                            : () => onCambiarCantidad(item.cantidad + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: ocupado ? null : onEliminar,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
