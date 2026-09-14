import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../../cu11_gestionar_reserva/data/reservas_api.dart';
import '../../cu11_gestionar_reserva/models/reserva.dart';
import '../../cu12_carrito/data/carrito_api.dart';
import '../../cu12_carrito/models/carrito.dart';
import '../data/compras_api.dart';
import 'confirmacion_compra_screen.dart';

/// Finalizar compra: resumen del carrito, sucursal, NIT y confirmación.
class CheckoutScreen extends StatefulWidget {
  final CarritoApi? carritoApi;
  final ReservasApi? sucursalesApi;
  final ComprasApi? api;

  const CheckoutScreen({super.key, this.carritoApi, this.sucursalesApi, this.api});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _nit = TextEditingController();
  CarritoDetalle? _carrito;
  List<SucursalCliente> _sucursales = [];
  int? _sucursal;
  String? _error;
  bool _busy = true;
  bool _confirmando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nit.dispose();
    super.dispose();
  }

  String? Function() get _credenciales =>
      () => context.read<SessionState>().credentialForApi;

  CarritoApi get _carritoApi =>
      widget.carritoApi ?? CarritoApi(credential: _credenciales);
  ReservasApi get _sucursalesApi =>
      widget.sucursalesApi ?? ReservasApi(credential: _credenciales);
  ComprasApi get _api => widget.api ?? ComprasApi(credential: _credenciales);

  Future<void> _cargar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final carrito = await _carritoApi.obtener();
      final sucursales = await _sucursalesApi.sucursales();
      if (!mounted) return;
      setState(() {
        _carrito = carrito;
        _sucursales = sucursales;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmar() async {
    if (!_form.currentState!.validate() || _sucursal == null || _confirmando) {
      if (_sucursal == null) setState(() => _error = 'Selecciona una sucursal.');
      return;
    }
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      final preparada =
          await _api.preparar(nroSuc: _sucursal!, nit: _nit.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => ConfirmacionCompraScreen(venta: preparada.venta)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar compra')),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null && _carrito == null) {
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
    final carrito = _carrito!;
    if (carrito.vacio) {
      return const Center(child: Text('No tienes productos en tu carrito para finalizar la compra.'));
    }
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Resumen del carrito', style: TextStyle(fontWeight: FontWeight.bold)),
          ...carrito.items.map((e) => ListTile(
                title: Text(e.producto),
                subtitle: Text('Talla ${e.talla} · ×${e.cantidad}'),
                trailing: Text('Bs ${e.subtotal.toStringAsFixed(2)}'),
              )),
          Text('Subtotal del carrito: Bs ${carrito.subtotal.toStringAsFixed(2)}'),
          const Text('Los descuentos y el total final se calculan al confirmar, según la promoción vigente.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
                labelText: 'Sucursal de atención', border: OutlineInputBorder()),
            initialValue: _sucursal,
            items: _sucursales
                .map((s) => DropdownMenuItem<int>(
                    value: s.nro, child: Text('${s.nombre} · ${s.ciudad}', overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _sucursal = v),
            validator: (v) => v == null ? 'Selecciona una sucursal' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nit,
            decoration:
                const InputDecoration(labelText: 'NIT (opcional)', border: OutlineInputBorder()),
            validator: (v) =>
                v != null && v.length > 30 ? 'Hasta 30 caracteres' : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirmando ? null : _confirmar,
            child: Text(_confirmando ? 'Preparando…' : 'Confirmar compra'),
          ),
        ],
      ),
    );
  }
}
