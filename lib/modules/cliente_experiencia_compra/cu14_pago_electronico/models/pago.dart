// Modelos CU14: reflejan el JSON de /api/cliente/pagos sin inventar atributos.

class PagoDetalle {
  final int idPago;
  final String metodo;
  final double monto;
  final String estado;
  final String fechaHora;
  final String? referencia;
  final int nroVenta;
  final String estadoVenta;

  const PagoDetalle({
    required this.idPago,
    required this.metodo,
    required this.monto,
    required this.estado,
    required this.fechaHora,
    required this.referencia,
    required this.nroVenta,
    required this.estadoVenta,
  });

  static double _numero(dynamic value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  factory PagoDetalle.fromJson(Map<String, dynamic> json) => PagoDetalle(
        idPago: (json['idPago'] as num).toInt(),
        metodo: json['metodo'] as String,
        monto: _numero(json['monto']),
        estado: json['estado'] as String,
        fechaHora: json['fechaHora'] as String,
        referencia: json['referencia'] as String?,
        nroVenta: (json['nroVenta'] as num).toInt(),
        estadoVenta: json['estadoVenta'] as String,
      );

  bool get aprobado => estado == 'aprobado';
  bool get rechazado => estado == 'rechazado';
  bool get pendiente => estado == 'pendiente';
}

class PagoPreparado {
  final PagoDetalle pago;
  final bool reutilizado;

  const PagoPreparado({required this.pago, required this.reutilizado});
}
