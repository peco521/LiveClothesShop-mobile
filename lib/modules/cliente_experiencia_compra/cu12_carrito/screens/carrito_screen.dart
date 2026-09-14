import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/carrito_api.dart';
import '../models/carrito.dart';

/// Carrito: items con cantidad editable, precios del servidor y subtotal.
class CarritoScreen extends StatefulWidget {
  final CarritoApi? api;

  const CarritoScreen({super.key, this.api});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  CarritoDetalle? _carrito;
  String? _error;
  bool _busy = true;
  bool _mutando = false;

  CarritoApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return CarritoApi(credential: () => context.read<SessionState>().credentialForApi);
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
      final carrito = await _api.obtener();
      if (!mounted) return;
      setState(() => _carrito = carrito);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutar(Future<CarritoDetalle> Function() operacion) async {
    setState(() {
      _mutando = true;
      _error = null;
    });
    try {
      final carrito = await operacion();
      if (!mounted) return;
      setState(() => _carrito = carrito);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
      await _cargar();
    } finally {
      if (mounted) setState(() => _mutando = false);
    }
  }

  Future<void> _editarCantidad(CarritoItem item) async {
    final controlador = TextEditingController(text: '${item.cantidad}');
    final nueva = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cantidad'),
        content: TextField(
          controller: controlador,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nueva cantidad'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controlador.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nueva == null || !mounted) return;
    if (nueva < 1) {
      setState(() => _error = 'La cantidad debe ser mayor a cero.');
      return;
    }
    await _mutar(() => _api.modificar(item.idDetalle, nueva));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carrito')),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64),
            const SizedBox(height: 12),
            const Text('No tienes productos en tu carrito.'),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Explorar el catálogo'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: carrito.items.length,
            itemBuilder: (context, i) => _tarjeta(carrito.items[i]),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${carrito.cantidadItems} prendas',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Subtotal: Bs ${carrito.subtotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/tienda/finalizar-compra'),
                    child: const Text('Finalizar compra'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(CarritoItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            item.imagen != null
                ? Image.network(item.imagen!, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 40))
                : const Icon(Icons.checkroom, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.producto, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Talla ${item.talla} · ${item.colores.join(', ')}'),
                  Text('Bs ${item.precio.toStringAsFixed(2)} c/u'),
                  if (!item.disponible)
                    Text('No disponible actualmente (quedan ${item.cantidadDisponible}).',
                        style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Disminuir',
                      onPressed: _mutando || item.cantidad <= 1
                          ? null
                          : () => _mutar(() => _api.modificar(item.idDetalle, item.cantidad - 1)),
                    ),
                    InkWell(
                      onTap: _mutando ? null : () => _editarCantidad(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('${item.cantidad}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Aumentar',
                      onPressed: _mutando ? null : () => _mutar(() => _api.modificar(item.idDetalle, item.cantidad + 1)),
                    ),
                  ],
                ),
                Text('Bs ${item.subtotal.toStringAsFixed(2)}'),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar',
                  onPressed: _mutando ? null : () => _mutar(() => _api.eliminar(item.idDetalle)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
