import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/ra_contexto.dart';

/// Panel inferior del probador: qué prenda se está probando y cómo volver.
class RaControls extends StatelessWidget {
  const RaControls({super.key, required this.contexto, required this.onVolver});

  final RaContexto contexto;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final detalle = contexto.detalle;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.gapLarge),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contexto.descripcion,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detalle, style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 4),
          // La talla es contexto: CU16 no mide el cuerpo.
          const Text(
            'Prueba visual: no mide tu talla ni modifica tu pedido.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: AppTheme.gap),
          OutlinedButton.icon(
            onPressed: onVolver,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al producto'),
          ),
        ],
      ),
    );
  }
}
