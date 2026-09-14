import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/models/reserva.dart';

void main() {
  group('ReservaDetalle', () {
    test('fromJson conserva campos y calcula cancelable', () {
      final item = ReservaDetalle.fromJson({
        'nroReserva': 7,
        'fechaReserva': '2026-09-20',
        'horaAtencion': '10:00:00',
        'estado': 'pendiente',
        'sucursal': {'nro': 1, 'nombre': 'Central', 'ciudad': 'La Paz'},
        'items': [
          {'idDetalleRes': 1, 'idVar': 'v1', 'sku': 'SKU-1', 'producto': 'Camisa', 'cantidad': 2}
        ],
        'totalUnidades': 2,
        'vencida': false,
      });
      expect(item.nroReserva, 7);
      expect(item.cancelable, isTrue);
      expect(item.items.single.producto, 'Camisa');
      expect(
        ReservaDetalle.fromJson({..._json(), 'estado': 'confirmada'}).cancelable,
        isFalse,
      );
    });
  });

  group('ReservaCrear', () {
    test('toJson sin identidad del cliente', () {
      final body = const ReservaCrear(
        nroSuc: 1,
        fechaReserva: '2026-09-20',
        horaAtencion: '10:00',
        items: [ReservaItemCrear(idVar: 'v1', cantidad: 2)],
      ).toJson();
      expect(body, {
        'nroSuc': 1,
        'fechaReserva': '2026-09-20',
        'horaAtencion': '10:00',
        'items': [
          {'idVar': 'v1', 'cantidad': 2}
        ],
      });
      expect(jsonKeys(body), isNot(contains('idUsuarioCl')));
    });
  });
}

Map<String, dynamic> _json() => {
      'nroReserva': 7,
      'fechaReserva': '2026-09-20',
      'horaAtencion': '10:00:00',
      'estado': 'pendiente',
      'sucursal': {'nro': 1, 'nombre': 'Central', 'ciudad': 'La Paz'},
      'items': [],
      'totalUnidades': 0,
      'vencida': false,
    };

Iterable<String> jsonKeys(Map<String, dynamic> json) => json.keys;
