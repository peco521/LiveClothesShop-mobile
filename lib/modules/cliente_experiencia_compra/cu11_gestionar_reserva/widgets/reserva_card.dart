import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../models/reserva.dart';

/// Tarjeta de una reserva (CU11).
class ReservaCard extends StatelessWidget {
  const ReservaCard({super.key, required this.reserva, required this.onTap});

  final Reserva reserva;
  final VoidCallback onTap;

  Color get _colorEstado => switch (reserva.estado) {
    'confirmada' => AppColors.accent,
    'pendiente' => AppColors.muted,
    'atendida' => AppColors.success,
    'cancelada' || 'vencida' => AppColors.danger,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Reserva #${reserva.nroReserva}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    etiquetaReserva(reserva.estado),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _colorEstado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${fecha(reserva.fechaReserva)} · ${hora(reserva.horaAtencion)}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              Text(
                '${reserva.sucursal.nombre} · ${reserva.sucursal.ciudad}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                '${reserva.totalUnidades} unidad(es) en ${reserva.items.length} polera(s)',
                style: const TextStyle(fontSize: 13),
              ),
              if (reserva.vencida)
                const Text(
                  'Reserva vencida: el tiempo de atención ya pasó.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              const SizedBox(height: 6),
              for (final item in reserva.items.take(3))
                Text(
                  '• ${item.producto} × ${item.cantidad}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
