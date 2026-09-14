import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/pagos_api.dart';
import 'estado_pago_screen.dart';

const _metodos = ['tarjeta', 'QR', 'transferencia'];
const _metodoTexto = {'tarjeta': 'Tarjeta', 'QR': 'QR', 'transferencia': 'Transferencia'};
const _escenarios = ['aprobado', 'rechazado', 'timeout'];

/// Pago electrónico (mock académico): elige medio y resultado simulado.
class PagoScreen extends StatefulWidget {
  final int nroVenta;
  final PagosApi? api;

  const PagoScreen({super.key, required this.nroVenta, this.api});

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  final _form = GlobalKey<FormState>();
  String _metodo = 'tarjeta';
  String _escenario = 'aprobado';
  String? _error;
  bool _busy = false;

  PagosApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return PagosApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  Future<void> _pagar() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preparado = await _api.pagar(
          nroVenta: widget.nroVenta, metodo: _metodo, escenario: _escenario);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => EstadoPagoScreen(pago: preparado.pago, api: widget.api)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pago')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'Entorno de prueba/simulación: no ingreses datos financieros reales. Solo eliges el medio de pago; el monto lo determina la venta.'),
            const SizedBox(height: 12),
            Text('Vas a pagar la compra número ${widget.nroVenta}.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Medio de pago', border: OutlineInputBorder()),
              initialValue: _metodo,
              items: _metodos
                  .map((m) => DropdownMenuItem(value: m, child: Text(_metodoTexto[m]!)))
                  .toList(),
              onChanged: (v) => setState(() => _metodo = v ?? 'tarjeta'),
            ),
            const SizedBox(height: 12),
            const Text('Simulación académica: el resultado lo genera una pasarela de prueba.'),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Resultado simulado', border: OutlineInputBorder()),
              initialValue: _escenario,
              items: _escenarios
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _escenario = v ?? 'aprobado'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _pagar,
              child: Text(_busy ? 'Procesando…' : 'Realizar pago'),
            ),
          ],
        ),
      ),
    );
  }
}
