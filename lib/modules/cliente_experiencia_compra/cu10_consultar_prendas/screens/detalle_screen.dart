import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/catalogo_api.dart';
import '../models/catalogo.dart';
import '../../cu12_carrito/data/carrito_api.dart';

/// Detalle de prenda: variantes, talla, colores, precio y disponibilidad.
class DetalleScreen extends StatefulWidget {
  final String idProd;
  final CatalogoApi? api;
  final CarritoApi? carritoApi;

  const DetalleScreen({super.key, required this.idProd, this.api, this.carritoApi});

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  ProductoDetalle? _item;
  String? _error;
  bool _busy = true;
  String? _seleccionada;
  int _cantidad = 1;
  bool _agregando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  CatalogoApi get _api {
    final api = widget.api;
    if (api != null) return api;
    return CatalogoApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  CarritoApi get _carrito {
    final api = widget.carritoApi;
    if (api != null) return api;
    return CarritoApi(credential: () => context.read<SessionState>().credentialForApi);
  }

  Future<void> _cargar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await _api.detalle(widget.idProd);
      if (!mounted) return;
      setState(() {
        _item = item;
        if (item.variantes.length == 1) _seleccionada = item.variantes.first.id;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _agregar() async {
    final idVar = _seleccionada;
    if (idVar == null || _agregando) return;
    setState(() => _agregando = true);
    try {
      await _carrito.agregar(idVar, _cantidad);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Prenda agregada al carrito.'),
          action: SnackBarAction(
            label: 'Ver carrito',
            onPressed: () => Navigator.of(context).pushNamed('/tienda/carrito'),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de prenda')),
      body: _cuerpo(),
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
            FilledButton.tonal(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final item = _item!;
    final filas = _seleccionada == null
        ? item.disponibilidad
        : item.disponibilidadDe(_seleccionada!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(item.descripcion, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('${item.marca} · ${item.categoria} · ${item.coleccion}'),
        if (item.promocion != null) Chip(label: Text('Promoción: ${item.promocion}')),
        const SizedBox(height: 12),
        Text('Variantes (${item.variantes.length})', style: Theme.of(context).textTheme.titleMedium),
        if (item.variantes.isEmpty) const Text('Esta prenda no tiene variantes activas por el momento.'),
        ...item.variantes.map((v) => Card(
              color: _seleccionada == v.id ? Theme.of(context).colorScheme.primaryContainer : null,
              child: ListTile(
                leading: v.imagen != null
                    ? Image.network(v.imagen!, width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported))
                    : const Icon(Icons.checkroom),
                title: Text('Talla ${v.talla.descripcion} · Bs ${v.precio.toStringAsFixed(2)}'),
                subtitle: Text(v.colores.isEmpty
                    ? 'Sin color registrado'
                    : v.colores.map((c) => c.descripcion).join(', ')),
                trailing: _seleccionada == v.id ? const Icon(Icons.check_circle) : null,
                onTap: () => setState(() => _seleccionada = v.id),
              ),
            )),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.event_note),
          label: const Text('Reservar esta variante'),
          onPressed: _seleccionada == null
              ? null
              : () => Navigator.of(context).pushNamed(
                    '/tienda/reservas/nueva',
                    arguments: {'idVar': _seleccionada, 'cantidad': 1},
                  ),
        ),
        const SizedBox(height: 8),
        if (_seleccionada != null)
          Row(
            children: [
              const Text('Cantidad:'),
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: 'Disminuir',
                onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
              ),
              Text('$_cantidad', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Aumentar',
                onPressed: () => setState(() => _cantidad++),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(_agregando ? 'Agregando…' : 'Agregar al carrito'),
                  onPressed: _agregando ? null : _agregar,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text('Disponibilidad por sucursal', style: Theme.of(context).textTheme.titleMedium),
        if (filas.isEmpty)
          const Text('Sin existencias disponibles en sucursales activas.')
        else
          ...filas.map((d) => ListTile(
                leading: const Icon(Icons.store),
                title: Text('${d.sucursal} · ${d.ciudad}'),
                subtitle: Text('Variante ${d.idVariante}'),
                trailing: Text('${d.cantDisp} disp.', style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
      ],
    );
  }
}
