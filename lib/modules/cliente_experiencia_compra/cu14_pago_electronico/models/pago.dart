/// Modelos de CU14 Pago electrónico (`/api/cliente/pagos`).
class ConfiguracionPago {
  const ConfiguracionPago({
    required this.proveedor,
    required this.simulacion,
    required this.disponible,
    this.moneda,
  });

  final String proveedor;
  final bool simulacion;
  final bool disponible;
  final String? moneda;

  factory ConfiguracionPago.fromJson(Map<String, dynamic> json) =>
      ConfiguracionPago(
        proveedor: json['proveedor']?.toString() ?? '',
        simulacion: json['simulacion'] as bool? ?? false,
        disponible: json['disponible'] as bool? ?? false,
        moneda: json['moneda']?.toString(),
      );
}

/// Pago de una venta. `checkoutUrl` es la página segura de Stripe: la app la abre
/// con url_launcher y NUNCA pide datos de tarjeta.
class PagoDetalle {
  const PagoDetalle({
    required this.idPago,
    required this.metodo,
    required this.monto,
    required this.estado,
    required this.nroVenta,
    required this.estadoVenta,
    this.fechaHora,
    this.referencia,
    this.checkoutUrl,
  });

  final int idPago;
  final String metodo;
  final double monto;
  final String estado;
  final int nroVenta;
  final String estadoVenta;
  final DateTime? fechaHora;
  final String? referencia;
  final String? checkoutUrl;

  bool get aprobado => estado == 'aprobado';
  bool get pendiente => estado == 'pendiente';
  bool get rechazado => estado == 'rechazado';

  factory PagoDetalle.fromJson(Map<String, dynamic> json) => PagoDetalle(
    idPago: json['idPago'] as int? ?? 0,
    metodo: json['metodo']?.toString() ?? '',
    monto: _numero(json['monto']),
    estado: json['estado']?.toString() ?? '',
    nroVenta: json['nroVenta'] as int? ?? 0,
    estadoVenta: json['estadoVenta']?.toString() ?? '',
    fechaHora: DateTime.tryParse(json['fechaHora']?.toString() ?? '')
        ?.toLocal(),
    referencia: json['referencia']?.toString(),
    checkoutUrl: json['checkoutUrl']?.toString(),
  );
}

double _numero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
