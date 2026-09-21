import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/models/compra.dart';

void main() {
  group('VentaDetalle', () {
    test('fromJson conserva cantidades, precios y totales', () {
      final venta = VentaDetalle.fromJson({
        'nroVenta': 11,
        'fechaHora': '2026-09-13T10:00:00',
        'estado': 'registrada',
        'nit': null,
        'sucursal': {'nro': 1, 'nombre': 'Central', 'ciudad': 'La Paz'},
        'carrito': 5,
        'items': [
          {
            'idDetalleVenta': 1,
            'idVar': 'v1',
            'sku': 'SKU-1',
            'producto': 'Camisa',
            'cantidad': 3,
            'precioUnitario': 120,
            'subtotalBruto': 360,
            'descuento': 36,
          }
        ],
        'brutoTotal': 360,
        'descAplicado': 36,
        'total': 324,
      });
      expect(venta.nroVenta, 11);
      expect(venta.estado, 'registrada');
      final item = venta.items.single;
      expect(item.cantidad, 3);
      expect(item.precioUnitario, 120);
      expect(venta.total, 324);
    });
  });
}
