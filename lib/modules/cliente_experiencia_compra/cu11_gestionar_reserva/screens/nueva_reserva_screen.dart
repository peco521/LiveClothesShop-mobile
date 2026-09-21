import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../models/reserva.dart';
import '../providers/reservas_provider.dart';

/// CU11 Nueva reserva de una variante concreta (llega desde CU10).
class NuevaReservaScreen extends ConsumerStatefulWidget {
  const NuevaReservaScreen({super.key, required this.idVar, this.cantidad = 1});

  static const String routePath = '/reserva/nueva';

  final String idVar;
  final int cantidad;

  @override
  ConsumerState<NuevaReservaScreen> createState() => _NuevaReservaScreenState();
}

class _NuevaReservaScreenState extends ConsumerState<NuevaReservaScreen> {
  int? _nroSuc;
  DateTime? _fecha;
  String? _hora;
  bool _enviando = false;
  String? _aviso;

  String? get _fechaTexto {
    final fecha = _fecha;
    if (fecha == null) return null;
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year.toString().padLeft(4, '0')}-$mes-$dia';
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: hoy.subtract(const Duration(days: 1)),
      lastDate: hoy.add(const Duration(days: 30)),
      helpText: 'Día de retiro',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  /// Horas disponibles según los rangos declarados por la sucursal.
  List<String> _horas(HorariosSucursal horarios) {
    final valores = <String>[];
    for (final rango in horarios.rangos) {
      final inicio = int.tryParse(rango.horaIni.split(':').first) ?? 9;
      final fin = int.tryParse(rango.horaFin.split(':').first) ?? 18;
      for (var hora = inicio; hora < fin; hora++) {
        valores.add('${hora.toString().padLeft(2, '0')}:00:00');
      }
    }
    return valores.toSet().toList()..sort();
  }

  Future<void> _confirmar() async {
    if (_nroSuc == null || _fechaTexto == null || _hora == null) {
      setState(() => _aviso = 'Selecciona sucursal, fecha y hora de atención.');
      return;
    }
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      final reserva = await ref
          .read(reservasProvider.notifier)
          .crear(
            nroSuc: _nroSuc!,
            fechaReserva: _fechaTexto!,
            horaAtencion: _hora!,
            items: [
              {'idVar': widget.idVar, 'cantidad': widget.cantidad},
            ],
          );
      if (mounted) context.go('/reservas/${reserva.nroReserva}');
    } on AppException catch (error) {
      setState(() => _aviso = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sucursales = ref.watch(sucursalesProvider);
    final horarios = _nroSuc == null
        ? null
        : ref.watch(horariosSucursalProvider(_nroSuc!));
    final datosHorarios = horarios?.asData?.value;
    final horas = datosHorarios == null
        ? const <String>[]
        : _horas(datosHorarios);
    return Scaffold(
      appBar: AppBar(title: const Text('Reservar polera')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gapLarge),
        children: [
          Text(
            'Variante: ${widget.idVar}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Cantidad reservada: ${widget.cantidad}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: AppTheme.gapLarge),
          if (_aviso != null) ...[
            ErrorView(message: _aviso!),
            const SizedBox(height: AppTheme.gap),
          ],
          sucursales.when(
            loading: () => const LoadingView(message: 'Cargando sucursales…'),
            error: (error, _) => ErrorView(
              message: mensajeDeError(error),
              onRetry: () => ref.invalidate(sucursalesProvider),
            ),
            data: (lista) => DropdownButtonFormField<int>(
              initialValue: _nroSuc,
              decoration: const InputDecoration(
                labelText: 'Sucursal de retiro',
              ),
              items: [
                for (final sucursal in lista)
                  DropdownMenuItem(
                    value: sucursal.nro,
                    child: Text('${sucursal.nombre} · ${sucursal.ciudad}'),
                  ),
              ],
              onChanged: (value) => setState(() {
                _nroSuc = value;
                _hora = null;
              }),
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          OutlinedButton(
            onPressed: _enviando ? null : _elegirFecha,
            child: Text(_fechaTexto ?? 'Selecciona el día de retiro'),
          ),
          const SizedBox(height: AppTheme.gap),
          if (_nroSuc != null)
            horarios!.when(
              loading: () => const LoadingView(message: 'Cargando horarios…'),
              error: (error, _) => ErrorView(
                message: mensajeDeError(error),
                onRetry: () =>
                    ref.invalidate(horariosSucursalProvider(_nroSuc!)),
              ),
              data: (data) => horas.isEmpty
                  ? const Text(
                      'La sucursal no declaró horarios de atención.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _hora,
                      decoration: const InputDecoration(
                        labelText: 'Hora de atención',
                      ),
                      items: [
                        for (final hora in horas)
                          DropdownMenuItem(
                            value: hora,
                            child: Text(hora.substring(0, 5)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _hora = value),
                    ),
            ),
          const SizedBox(height: AppTheme.gapLarge),
          ElevatedButton(
            onPressed: _enviando ? null : _confirmar,
            child: Text(_enviando ? 'Reservando…' : 'Confirmar reserva'),
          ),
          const SizedBox(height: AppTheme.gap),
          OutlinedButton(
            onPressed: _enviando ? null : () => context.pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
