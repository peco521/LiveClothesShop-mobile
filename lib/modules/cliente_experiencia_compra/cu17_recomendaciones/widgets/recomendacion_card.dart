import 'package:flutter/material.dart';

import '../../shared/widgets/producto_card.dart';
import '../models/recomendacion.dart';

/// Tarjeta de CU17: reutiliza la tarjeta de CU10 (misma identidad visual) y le
/// añade los motivos que envía el backend, sin mostrar porcentajes inventados.
class RecomendacionCard extends StatelessWidget {
  const RecomendacionCard({
    super.key,
    required this.recomendacion,
    required this.onTap,
  });

  final RecomendacionItem recomendacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProductoCard(
      producto: recomendacion.producto,
      // El backend puede devolver varias razones: en móvil se muestran dos como máximo.
      razones: recomendacion.razones.take(2).toList(),
      desdeTexto: true,
      onTap: onTap,
    );
  }
}
