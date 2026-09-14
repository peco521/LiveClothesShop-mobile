import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/reservas_api.dart';
import '../models/reserva.dart';

/// Nueva reserva: sucursal, fecha/hora e items (variante + cantidad).
class NuevaReservaScreen extends StatefulWidget {
  final ReservasApi? api;
  final String? idVarInicial;
  final int cantidadInicial;

  const NuevaReservaScreen({super.key, this.api, this.idVarInicial, this.cantidadInicial = 1});

  @override
  State<NuevaReservaScreen> createState() => _NuevaReservaScreenState();
}

class _ItemFila {
  final TextEditingController variante;
  final TextEditingController cantidad;
  _ItemFila(String idVar, int cantidad)
      : variante = TextEditingController(text: idVar),
        cantidad = TextEditingController(text: '$cantidad');
}

class _NuevaReservaScreenState extends State<NuevaReservaScreen> {
  final _form = GlobalKey<FormState>();
  int? _sucursal;
  DateTime _fecha = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  final List<_ItemFila> _items = [];
  List<SucursalCliente> _sucursales = [];
  List<HorarioRango> _horarios = [];
  bool _busy = false;
  String? _error;

  ReservasApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return ReservasApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  @override
  void initState() {
    super.initState();
    if (widget.idVarInicial != null) _items.add(_ItemFila(widget.idVarInicial!, widget.cantidadInicial));
    _cargarSucursales();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.variante.dispose();
      item.cantidad.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarSucursales() async {
    try {
      final rows = await _api.sucursales();
      if (!mounted) return;
      setState(() => _sucursales = rows);
    } catch (_) {
      // Se informa al guardar; la lista puede reintentarse saliendo y entrando.
    }
  }

  Future<void> _cargarHorarios(int nro) async {
    try {
      final rangos = await _api.horarios(nro);
      if (mounted) setState(() => _horarios = rangos);
    } catch (_) {
      if (mounted) setState(() => _horarios = []);
    }
  }

  String _fechaTexto(DateTime f) =>
      '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 1, hoy.month, hoy.day),
    );
    if (elegida != null && mounted) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(context: context, initialTime: _hora);
    if (elegida != null && mounted) setState(() => _hora = elegida);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate() || _sucursal == null || _items.isEmpty || _busy) {
      if (_sucursal == null || _items.isEmpty) {
        setState(() => _error = 'Selecciona sucursal y añade al menos una prenda.');
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final creada = await _api.crear(ReservaCrear(
        nroSuc: _sucursal!,
        fechaReserva: _fechaTexto(_fecha),
        horaAtencion:
            '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}',
        items: _items
            .map((e) => ReservaItemCrear(
                idVar: e.variante.text.trim(), cantidad: int.parse(e.cantidad.text.trim())))
            .toList(),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(creada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = 'Revisa las cantidades: deben ser números enteros mayores a cero.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva reserva')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                  labelText: 'Sucursal donde probarás las prendas', border: OutlineInputBorder()),
              initialValue: _sucursal,
              items: _sucursales
                  .map((s) => DropdownMenuItem<int>(
                      value: s.nro, child: Text('${s.nombre} · ${s.ciudad}', overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _sucursal = v;
                  _horarios = [];
                });
                if (v != null) _cargarHorarios(v);
              },
              validator: (v) => v == null ? 'Selecciona una sucursal' : null,
            ),
            if (_horarios.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Atiende: ${_horarios.map((r) => '${r.ini}–${r.fin}').join(', ')}.'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_fechaTexto(_fecha)),
                    onPressed: _elegirFecha,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_hora.format(context)),
                    onPressed: _elegirHora,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Prendas a reservar', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_items.isEmpty) const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Todavía no agregaste prendas.'),
            ),
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final fila = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: fila.variante,
                          decoration: const InputDecoration(labelText: 'Variante'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: fila.cantidad,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cantidad'),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            return (n == null || n < 1) ? 'Mínimo 1' : null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Quitar',
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Añadir prenda'),
              onPressed: () => setState(() => _items.add(_ItemFila('', 1))),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              child: Text(_busy ? 'Reservando…' : 'Confirmar reserva'),
            ),
          ],
        ),
      ),
    );
  }
}
