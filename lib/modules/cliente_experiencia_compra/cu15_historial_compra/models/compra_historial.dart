/// Modelos de CU15 Consultar historial de compras
/// (`/api/cliente/historial-compras`).
class ProductoCompraResumen {
  const ProductoCompraResumen({
    required this.idVar,
    required this.sku,
    required this.producto,
    required this.cantidad,
  });

  final String idVar;
  final String sku;
  final String producto;
  final int cantidad;

  factory ProductoCompraResumen.fromJson(Map<String, dynamic> json) =>
      ProductoCompraResumen(
        idVar: json['idVar']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        producto: json['producto']?.toString() ?? '',
        cantidad: json['cantidad'] as int? ?? 0,
      );
}

class CompraResumen {
  const CompraResumen({
    required this.nroVenta,
    required this.monto,
    required this.estado,
    this.fechaHora,
    this.estadoPago,
    this.productos = const [],
  });

  final int nroVenta;
  final double monto;
  final String estado;
  final DateTime? fechaHora;
  final String? estadoPago;
  final List<ProductoCompraResumen> productos;

  factory CompraResumen.fromJson(Map<String, dynamic> json) => CompraResumen(
    nroVenta: json['nroVenta'] as int? ?? 0,
    monto: _numero(json['monto']),
    estado: json['estado']?.toString() ?? '',
    fechaHora: DateTime.tryParse(json['fechaHora']?.toString() ?? '')
        ?.toLocal(),
    estadoPago: json['estadoPago']?.toString(),
    productos: (json['productos'] as List? ?? const [])
        .map(
          (item) => ProductoCompraResumen.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList(),
  );
}

class HistorialCompras {
  const HistorialCompras({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.limit = 20,
    this.mensaje,
  });

  final List<CompraResumen> items;
  final int total;
  final int offset;
  final int limit;
  final String? mensaje;

  factory HistorialCompras.fromJson(Map<String, dynamic> json) =>
      HistorialCompras(
        items: (json['items'] as List? ?? const [])
            .map(
              (item) =>
                  CompraResumen.fromJson((item as Map).cast<String, dynamic>()),
            )
            .toList(),
        total: json['total'] as int? ?? 0,
        offset: json['offset'] as int? ?? 0,
        limit: json['limit'] as int? ?? 20,
        mensaje: json['mensaje']?.toString(),
      );
}

class CompraItemDetalle {
  const CompraItemDetalle({
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

  factory CompraItemDetalle.fromJson(Map<String, dynamic> json) =>
      CompraItemDetalle(
        idDetalleVenta: json['idDetalleVenta'] as int? ?? 0,
        idVar: json['idVar']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        producto: json['producto']?.toString() ?? '',
        cantidad: json['cantidad'] as int? ?? 0,
        precioUnitario: _numero(json['precioUnitario']),
        subtotalBruto: _numero(json['subtotalBruto']),
      );
}

class CompraSucursal {
  const CompraSucursal({
    required this.nro,
    required this.nombre,
    required this.ciudad,
  });

  final int nro;
  final String nombre;
  final String ciudad;

  factory CompraSucursal.fromJson(Map<String, dynamic> json) => CompraSucursal(
    nro: json['nro'] as int? ?? 0,
    nombre: json['nombre']?.toString() ?? '',
    ciudad: json['ciudad']?.toString() ?? '',
  );
}

class CompraPago {
  const CompraPago({
    required this.idPago,
    required this.metodo,
    required this.monto,
    required this.estado,
    this.fechaHora,
    this.referencia,
  });

  final int idPago;
  final String metodo;
  final double monto;
  final String estado;
  final DateTime? fechaHora;
  final String? referencia;

  factory CompraPago.fromJson(Map<String, dynamic> json) => CompraPago(
    idPago: json['idPago'] as int? ?? 0,
    metodo: json['metodo']?.toString() ?? '',
    monto: _numero(json['monto']),
    estado: json['estado']?.toString() ?? '',
    fechaHora: DateTime.tryParse(json['fechaHora']?.toString() ?? '')
        ?.toLocal(),
    referencia: json['referencia']?.toString(),
  );
}

class CompraDetalle {
  const CompraDetalle({
    required this.nroVenta,
    required this.estado,
    required this.sucursal,
    required this.brutoTotal,
    required this.descAplicado,
    required this.total,
    this.fechaHora,
    this.estadoPago,
    this.nit,
    this.idCarrito,
    this.nroReserva,
    this.items = const [],
    this.pago,
  });

  final int nroVenta;
  final String estado;
  final CompraSucursal sucursal;
  final double brutoTotal;
  final double descAplicado;
  final double total;
  final DateTime? fechaHora;
  final String? estadoPago;
  final String? nit;
  final int? idCarrito;
  final int? nroReserva;
  final List<CompraItemDetalle> items;
  final CompraPago? pago;

  factory CompraDetalle.fromJson(Map<String, dynamic> json) => CompraDetalle(
    nroVenta: json['nroVenta'] as int? ?? 0,
    estado: json['estado']?.toString() ?? '',
    sucursal: CompraSucursal.fromJson(
      (json['sucursal'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    brutoTotal: _numero(json['brutoTotal']),
    descAplicado: _numero(json['descAplicado']),
    total: _numero(json['total']),
    fechaHora: DateTime.tryParse(json['fechaHora']?.toString() ?? '')
        ?.toLocal(),
    estadoPago: json['estadoPago']?.toString(),
    nit: json['nit']?.toString(),
    idCarrito: json['idCarrito'] as int?,
    nroReserva: json['nroReserva'] as int?,
    items: (json['items'] as List? ?? const [])
        .map(
          (item) =>
              CompraItemDetalle.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
    pago: json['pago'] == null
        ? null
        : CompraPago.fromJson((json['pago'] as Map).cast<String, dynamic>()),
  );
}

double _numero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
