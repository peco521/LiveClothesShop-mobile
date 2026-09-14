import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/models/pago.dart';

void main() {
  group('PagoDetalle', () {
    test('fromJson conserva monto de la venta y referencia mock', () {
      final pago = PagoDetalle.fromJson({
        'idPago': 3,
        'metodo': 'tarjeta',
        'monto': 180,
        'estado': 'aprobado',
        'fechaHora': '2026-09-13T10:05:00',
        'referencia': 'MOCK-000003-11',
        'nroVenta': 11,
        'estadoVenta': 'registrada',
      });
      expect(pago.aprobado, isTrue);
      expect(pago.monto, 180);
      expect(pago.referencia, 'MOCK-000003-11');
      expect(pago.pendiente, isFalse);
    });
  });
}
