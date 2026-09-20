/// Modelos de CU13 Compra digital (`/api/cliente/compras`).
class VentaItem {
  const VentaItem({
    required this.idDetalleVenta,
    required this.idVar,
    required this.sku,
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotalBruto,
  });

  final int idDetalleVenta;
  final String idVar;
  final String sku;
  final String producto;
  final int cantidad;
  final double precioUnitario;
  final double subtotalBruto;

  factory VentaItem.fromJson(Map<String, dynamic> json) => VentaItem(
    idDetalleVenta: json['idDetalleVenta'] as int? ?? 0,
    idVar: json['idVar']?.toString() ?? '',
    sku: json['sku']?.toString() ?? '',
    producto: json['producto']?.toString() ?? '',
    cantidad: json['cantidad'] as int? ?? 0,
    precioUnitario: _numero(json['precioUnitario']),
    subtotalBruto: _numero(json['subtotalBruto']),
  );
}

class VentaSucursal {
  const VentaSucursal({
    required this.nro,
    required this.nombre,
    required this.ciudad,
  });

  final int nro;
  final String nombre;
  final String ciudad;

  factory VentaSucursal.fromJson(Map<String, dynamic> json) => VentaSucursal(
    nro: json['nro'] as int? ?? 0,
    nombre: json['nombre']?.toString() ?? '',
    ciudad: json['ciudad']?.toString() ?? '',
  );
}

/// Venta pendiente de pago (CU13). Los importes SIEMPRE vienen del backend.
class VentaDetalle {
  const VentaDetalle({
    required this.nroVenta,
    required this.estado,
    required this.sucursal,
    required this.brutoTotal,
    required this.descAplicado,
    required this.total,
    this.fechaHora,
    this.nit,
    this.carrito,
    this.items = const [],
  });

  final int nroVenta;
  final String estado;
  final VentaSucursal sucursal;
  final double brutoTotal;
  final double descAplicado;
  final double total;
  final DateTime? fechaHora;
  final String? nit;
  final int? carrito;
  final List<VentaItem> items;

  factory VentaDetalle.fromJson(Map<String, dynamic> json) => VentaDetalle(
    nroVenta: json['nroVenta'] as int? ?? 0,
    estado: json['estado']?.toString() ?? '',
    sucursal: VentaSucursal.fromJson(
      (json['sucursal'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    brutoTotal: _numero(json['brutoTotal']),
    descAplicado: _numero(json['descAplicado']),
    total: _numero(json['total']),
    fechaHora: DateTime.tryParse(json['fechaHora']?.toString() ?? '')
        ?.toLocal(),
    nit: json['nit']?.toString(),
    carrito: json['carrito'] as int?,
    items: (json['items'] as List? ?? const [])
        .map(
          (item) => VentaItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
  );
}

double _numero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
