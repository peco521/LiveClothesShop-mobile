import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/reservas_api.dart';
import '../models/reserva.dart';

/// Detalle de reserva: items, sucursal, estado y cancelación en dos pasos.
class DetalleReservaScreen extends StatefulWidget {
  final int nro;
  final ReservasApi? api;

  const DetalleReservaScreen({super.key, required this.nro, this.api});

  @override
  State<DetalleReservaScreen> createState() => _DetalleReservaScreenState();
}

class _DetalleReservaScreenState extends State<DetalleReservaScreen> {
  ReservaDetalle? _item;
  String? _error;
  bool _busy = true;
  bool _confirmar = false;
  bool _cancelando = false;

  ReservasApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return ReservasApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await _api.detalle(widget.nro);
      if (!mounted) return;
      setState(() => _item = item);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelar() async {
    setState(() {
      _cancelando = true;
      _error = null;
    });
    try {
      final item = await _api.cancelar(widget.nro);
      if (!mounted) return;
      setState(() {
        _item = item;
        _confirmar = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null && _item == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final r = _item!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reserva ${r.nroReserva}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Chip(label: Text(r.vencida ? 'Vencida' : r.estado)),
        Text('${r.fecha} · ${r.hora}'),
        Text('${r.sucursal.nombre} · ${r.sucursal.ciudad}'),
        const SizedBox(height: 12),
        Text('Prendas (${r.totalUnidades})', style: Theme.of(context).textTheme.titleMedium),
        ...r.items.map((e) => ListTile(
              leading: const Icon(Icons.checkroom),
              title: Text(e.producto),
              subtitle: Text('${e.sku} · Variante ${e.idVar}'),
              trailing: Text('×${e.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (r.cancelable) ...[
          const SizedBox(height: 8),
          if (!_confirmar)
            OutlinedButton(onPressed: () => setState(() => _confirmar = true),
                child: const Text('Cancelar reserva'))
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _cancelando ? null : _cancelar,
                    child: Text(_cancelando ? 'Cancelando…' : 'Confirmar cancelación'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelando ? null : () => setState(() => _confirmar = false),
                    child: const Text('Volver'),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
