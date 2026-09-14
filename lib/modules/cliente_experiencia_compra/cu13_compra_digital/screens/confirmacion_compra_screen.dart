import 'package:flutter/material.dart';

import '../models/compra.dart';

/// Compra preparada: muestra la venta registrada pendiente de pago.
/// No implementa ni simula el pago (CU14).
class ConfirmacionCompraScreen extends StatelessWidget {
  final VentaDetalle venta;

  const ConfirmacionCompraScreen({super.key, required this.venta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compra preparada')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Compra ${venta.nroVenta}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Chip(label: Text(venta.estado)),
          Text('${venta.sucursal} · ${venta.ciudad}'),
          if (venta.nit != null) Text('NIT ${venta.nit}'),
          const SizedBox(height: 12),
          const Text('Detalle de la compra', style: TextStyle(fontWeight: FontWeight.bold)),
          ...venta.items.map((e) => ListTile(
                title: Text(e.producto),
                subtitle: Text('${e.sku} · ×${e.cantidad} · Bs ${e.precioUnitario.toStringAsFixed(2)} c/u'),
                trailing: Text('Bs ${e.subtotalBruto.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const SizedBox(height: 8),
          Text('Descuento: Bs ${venta.descAplicado.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium),
          Text('Total: Bs ${venta.total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text('Compra preparada para realizar el pago. El siguiente paso será realizar el pago electrónico.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pushNamed(
                '/tienda/pago',
                arguments: {'nroVenta': venta.nroVenta},
              ),
              child: const Text('Realizar pago'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Volver a la tienda'),
          ),
        ],
      ),
    );
  }
}
