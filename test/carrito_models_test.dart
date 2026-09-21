import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/models/carrito.dart';

void main() {
  group('CarritoDetalle', () {
    test('fromJson conserva items, subtotal y disponibilidad', () {
      final carrito = CarritoDetalle.fromJson({
        'idCarrito': 5,
        'items': [
          {
            'idDetalleCarro': 1,
            'idVar': 'v1',
            'sku': 'SKU-1',
            'imagen': 'http://img/1.jpg',
            'producto': 'Camisa Oxford',
            'talla': {'idTalla': 1, 'descripcion': 'M'},
            'colores': [
              {'idColor': 1, 'descripcion': 'Rojo', 'hex': '#FF0000'}
            ],
            'precio': 100,
            'promocion': {'idPromo': 1, 'nombre': 'Promo', 'tipoDescuento': 'porcentaje', 'valorDescuento': 10},
            'cantidad': 2,
            'subtotal': 200,
            'disponible': true,
            'cantidadDisponible': 4,
          }
        ],
        'cantidadItems': 2,
        'subtotal': 200,
      });
      expect(carrito.idCarrito, 5);
      expect(carrito.vacio, isFalse);
      final item = carrito.items.single;
      expect(item.talla, 'M');
      expect(item.colores, ['Rojo']);
      expect(item.promocion, 'Promo');
      expect(item.subtotal, 200);
    });

    test('vacío sin carrito', () {
      final carrito = CarritoDetalle.fromJson(
          {'idCarrito': null, 'items': [], 'cantidadItems': 0, 'subtotal': 0});
      expect(carrito.vacio, isTrue);
      expect(CarritoDetalle.vacio().idCarrito, isNull);
    });
  });
}
