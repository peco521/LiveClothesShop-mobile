// Modelos CU13: reflejan el JSON de /api/cliente/compras sin inventar atributos.

class VentaItem {
  final int idDetalle;
  final String idVar;
  final String sku;
  final String producto;
  final int cantidad;
  final double precioUnitario;
  final double subtotalBruto;

  const VentaItem({
    required this.idDetalle,
    required this.idVar,
    required this.sku,
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotalBruto,
  });

  static double _numero(dynamic value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  factory VentaItem.fromJson(Map<String, dynamic> json) => VentaItem(
        idDetalle: (json['idDetalleVenta'] as num).toInt(),
        idVar: json['idVar'] as String,
        sku: json['sku'] as String,
        producto: json['producto'] as String,
        cantidad: (json['cantidad'] as num).toInt(),
        precioUnitario: _numero(json['precioUnitario']),
        subtotalBruto: _numero(json['subtotalBruto']),
      );
}

class VentaDetalle {
  final int nroVenta;
  final String fechaHora;
  final String estado;
  final String? nit;
  final String sucursal;
  final String ciudad;
  final int carrito;
  final List<VentaItem> items;
  final double brutoTotal;
  final double descAplicado;
  final double total;

  const VentaDetalle({
    required this.nroVenta,
    required this.fechaHora,
    required this.estado,
    required this.nit,
    required this.sucursal,
    required this.ciudad,
    required this.carrito,
    required this.items,
    required this.brutoTotal,
    required this.descAplicado,
    required this.total,
  });

  static double _numero(dynamic value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  factory VentaDetalle.fromJson(Map<String, dynamic> json) {
    final sucursal = json['sucursal'] as Map<String, dynamic>;
    return VentaDetalle(
      nroVenta: (json['nroVenta'] as num).toInt(),
      fechaHora: json['fechaHora'] as String,
      estado: json['estado'] as String,
      nit: json['nit'] as String?,
      sucursal: sucursal['nombre'] as String,
      ciudad: sucursal['ciudad'] as String,
      carrito: (json['carrito'] as num).toInt(),
      items: ((json['items'] as List? ?? []).map((e) => VentaItem.fromJson(e as Map<String, dynamic>))).toList(),
      brutoTotal: _numero(json['brutoTotal']),
      descAplicado: _numero(json['descAplicado']),
      total: _numero(json['total']),
    );
  }
}

class CompraPreparada {
  final VentaDetalle venta;
  final bool reutilizada;

  const CompraPreparada({required this.venta, required this.reutilizada});
}
