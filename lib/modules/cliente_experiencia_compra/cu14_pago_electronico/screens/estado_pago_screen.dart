import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/pagos_api.dart';
import '../models/pago.dart';

/// Estado del pago: aprobado (compra completada), rechazado o pendiente.
class EstadoPagoScreen extends StatefulWidget {
  final PagoDetalle pago;
  final PagosApi? api;

  const EstadoPagoScreen({super.key, required this.pago, this.api});

  @override
  State<EstadoPagoScreen> createState() => _EstadoPagoScreenState();
}

class _EstadoPagoScreenState extends State<EstadoPagoScreen> {
  late PagoDetalle _pago;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pago = widget.pago;
  }

  PagosApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return PagosApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  Future<void> _consultar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pago = await _api.procesar(_pago.idPago);
      if (!mounted) return;
      setState(() => _pago = pago);
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
      appBar: AppBar(title: const Text('Estado del pago')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pago ${_pago.idPago}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Chip(label: Text(_pago.estado)),
          Text('Método: ${_pago.metodo} · Monto: Bs ${_pago.monto.toStringAsFixed(2)}'),
          if (_pago.referencia != null) Text('Referencia ${_pago.referencia}'),
          const SizedBox(height: 12),
          if (_pago.aprobado) ...[
            const Text('Compra completada. Tu pago fue aprobado y el inventario quedó actualizado.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Volver a la tienda'),
            ),
          ],
          if (_pago.rechazado) ...[
            const Text('Pago rechazado. Tu carrito sigue disponible para intentarlo nuevamente.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Volver al carrito'),
            ),
          ],
          if (_pago.pendiente) ...[
            const Text('Pago pendiente: aún no hay certeza del resultado. Puedes consultar su estado.'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _busy ? null : _consultar,
              child: Text(_busy ? 'Consultando…' : 'Consultar estado'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
