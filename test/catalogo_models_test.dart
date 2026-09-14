import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/catalogo.dart';

Map<String, dynamic> resumen() => {
      'idProd': 'prod-001',
      'descripcion': 'Camisa Oxford',
      'categoria': {'idCat': 1, 'descripcion': 'Camisas'},
      'marca': {'idMarca': 1, 'nombre': 'Andes'},
      'coleccion': {'idCol': 1, 'descripcion': 'Otoño'},
      'promocion': {'idPromo': 1, 'nombre': 'Promo', 'tipoDescuento': 'porcentaje', 'valorDescuento': 10},
      'precioMin': 100,
      'precioMax': 150,
      'imagen': 'http://img/1.jpg',
      'disponible': true,
      'totalVariantes': 2,
    };

void main() {
  group('ProductoResumen', () {
    test('fromJson conserva campos y calcula texto de precio', () {
      final item = ProductoResumen.fromJson(resumen());
      expect(item.idProd, 'prod-001');
      expect(item.marca, 'Andes');
      expect(item.promocion, 'Promo');
      expect(item.precioTexto, contains('100.00'));
      expect(item.disponible, isTrue);
    });

    test('sin precio muestra texto funcional', () {
      final item = ProductoResumen.fromJson({...resumen(), 'precioMin': null, 'precioMax': null});
      expect(item.precioTexto, 'Precio a consultar');
    });
  });

  group('ProductoDetalle', () {
    test('fromJson con variantes y disponibilidad', () {
      final item = ProductoDetalle.fromJson({
        ...resumen(),
        'estado': 'activo',
        'variantes': [
          {
            'idVariante': 'var-001',
            'sku': 'SKU-001',
            'precio': 100,
            'imagen': null,
            'talla': {'idTalla': 1, 'descripcion': 'M'},
            'colores': [
              {'idColor': 1, 'descripcion': 'Rojo', 'hex': '#FF0000'}
            ],
          }
        ],
        'disponibilidad': [
          {'nroSuc': 1, 'sucursal': 'Central', 'ciudad': 'La Paz', 'idVariante': 'var-001', 'stock': 10, 'cantDisp': 4}
        ],
      });
      expect(item.variantes, hasLength(1));
      expect(item.variantes.first.talla.descripcion, 'M');
      expect(item.disponibilidadDe('var-001'), hasLength(1));
      expect(item.disponibilidadDe('otra'), isEmpty);
    });
  });

  group('CatalogoFiltros', () {
    test('toQuery omite valores nulos y recorta búsqueda', () {
      final query = const CatalogoFiltros(q: '  Oxford ', categoria: 1, soloDisponibles: true).toQuery(0, 20);
      expect(query, {'offset': '0', 'limit': '20', 'q': 'Oxford', 'idCat': '1', 'soloDisponibles': 'true', 'sort': 'nombre_asc'});
    });
  });
}
