import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/ra_estado.dart';

/// Aviso de estado del probador: postura, prenda activa o falta de cámara.
class RaStatusOverlay extends StatelessWidget {
  const RaStatusOverlay({
    super.key,
    required this.estado,
    this.mensajeExtra,
    this.cargandoTextura = false,
  });

  final RaEstadoPose estado;

  /// Aviso puntual (por ejemplo "Preparando la prenda…").
  final String? mensajeExtra;
  final bool cargandoTextura;

  @override
  Widget build(BuildContext context) {
    final activa = estado == RaEstadoPose.activa;
    final fondo = activa ? AppColors.successBackground : AppColors.paper;
    final borde = activa ? AppColors.successBorder : AppColors.line;
    final color = activa ? AppColors.success : AppColors.ink;
    final texto = mensajeExtra ?? estado.mensaje;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: borde),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cargandoTextura)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(_icono(estado), size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(texto, style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icono(RaEstadoPose estado) => switch (estado) {
    RaEstadoPose.buscando => Icons.person_search_outlined,
    RaEstadoPose.activa => Icons.check_circle_outline,
    RaEstadoPose.sinTorso => Icons.accessibility_new,
    RaEstadoPose.sinCamara => Icons.no_photography_outlined,
  };
}
