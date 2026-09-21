import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/reservas_api.dart';
import '../models/reserva.dart';
import 'detalle_reserva_screen.dart';
import 'nueva_reserva_screen.dart';

/// Mis reservas: listado propio con filtro de estado y paginación.
class MisReservasScreen extends StatefulWidget {
  final ReservasApi? api;

  const MisReservasScreen({super.key, this.api});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  final List<ReservaDetalle> _items = [];
  int _total = 0;
  int _offset = 0;
  static const _limit = 20;
  String? _estado;
  bool _busy = false;
  bool _moreBusy = false;
  String? _error;

  ReservasApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return ReservasApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  @override
  void initState() {
    super.initState();
    _cargar(reset: true);
  }

  Future<void> _cargar({bool reset = false}) async {
    if (_busy || _moreBusy) return;
    setState(() {
      if (reset) {
        _busy = true;
        _error = null;
      } else {
        _moreBusy = true;
      }
    });
    try {
      final page = await _api.listar(estado: _estado, offset: reset ? 0 : _offset, limit: _limit);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _total = page.total;
        _offset = (reset ? 0 : _offset) + page.items.length;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _moreBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nueva reserva'),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NuevaReservaScreen(api: widget.api)),
          );
          if (mounted) _cargar(reset: true);
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
              initialValue: _estado,
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'confirmada', child: Text('Confirmada')),
                DropdownMenuItem(value: 'atendida', child: Text('Atendida')),
                DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
              ],
              onChanged: (v) {
                setState(() => _estado = v);
                _cargar(reset: true);
              },
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: () => _cargar(reset: true), child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_items.isEmpty) return const Center(child: Text('No tienes reservas registradas.'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: Text('$_total reservas encontradas.')),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final r = _items[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text('Reserva ${r.nroReserva} · ${r.sucursal.nombre}'),
                  subtitle: Text('${r.fecha} · ${r.hora} · ${r.totalUnidades} prendas'),
                  trailing: Chip(label: Text(r.vencida ? 'Vencida' : r.estado), visualDensity: VisualDensity.compact),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => DetalleReservaScreen(nro: r.nroReserva, api: widget.api)),
                    );
                    if (mounted) _cargar(reset: true);
                  },
                ),
              );
            },
          ),
        ),
        if (_items.length < _total)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonal(
              onPressed: _moreBusy ? null : () => _cargar(),
              child: Text(_moreBusy ? 'Cargando…' : 'Cargar más'),
            ),
          ),
      ],
    );
  }
}
