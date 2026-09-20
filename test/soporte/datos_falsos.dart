import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/producto.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/models/reserva.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/models/carrito.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/models/compra.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/models/pago.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu15_historial_compra/models/compra_historial.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/shared/models/producto_resumen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/shared/models/sesion.dart';

/// Datos de ejemplo con el MISMO contrato JSON del backend FastAPI.
Map<String, Object?> productoJson({
  String id = 'p1',
  String descripcion = 'Polera Nike Pro',
  String modelo = 'Deportiva',
  String marca = 'Nike',
  double precioMin = 45,
  double? precioMax,
  bool disponible = true,
  String? imagen,
}) => {
  'idProd': id,
  'descripcion': descripcion,
  'categoria': {'idCat': 1, 'descripcion': modelo},
  'marca': {'idMarca': 1, 'nombre': marca},
  'coleccion': {'idCol': 1, 'descripcion': 'Verano'},
  'promocion': null,
  'precioMin': precioMin,
  'precioMax': precioMax ?? precioMin,
  'imagen': imagen,
  'disponible': disponible,
  'totalVariantes': 1,
};

Map<String, Object?> productosJson({String id = 'p1'}) => {
  'items': [productoJson(id: id)],
  'total': 1,
  'offset': 0,
  'limit': 20,
};

Map<String, Object?> recomendacionJson({
  String id = 'p1',
  int score = 11,
  List<String> razones = const [
    'Similar a los modelos de polera que prefieres',
  ],
}) => {...productoJson(id: id), 'score': score, 'razones': razones};

Map<String, Object?> recomendacionesJson({
  String tipo = 'personalizada',
  List<Map<String, Object?>>? items,
}) => {
  'tipo': tipo,
  'mensaje': tipo == 'personalizada'
      ? 'Seleccionamos estas poleras según tus compras, reservas y productos de interés.'
      : 'Todavía estamos conociendo tus gustos. Estas son algunas poleras populares que podrían interesarte.',
  'total': items?.length ?? 1,
  'items': items ?? [recomendacionJson()],
};

Map<String, Object?> detalleProductoJson({String id = 'p1'}) => {
  'idProd': id,
  'descripcion': 'Polera Nike Pro',
  'estado': 'activo',
  'categoria': {'idCat': 1, 'descripcion': 'Deportiva'},
  'marca': {'idMarca': 1, 'nombre': 'Nike'},
  'coleccion': {'idCol': 1, 'descripcion': 'Verano'},
  'promocion': null,
  'variantes': [
    {
      'idVariante': 'v1',
      'sku': 'SKU-1',
      'precio': 45,
      'imagen': null,
      'talla': {'idTalla': 1, 'descripcion': 'M'},
      'colores': [
        {'idColor': 1, 'descripcion': 'Rojo', 'hex': '#FF0000'},
      ],
    },
  ],
  'disponibilidad': [
    {
      'nroSuc': 1,
      'sucursal': 'Central',
      'ciudad': 'La Paz',
      'idVariante': 'v1',
      'stock': 10,
      'cantDisp': 4,
    },
  ],
};

Map<String, Object?> carritoJson({bool vacio = false}) => {
  'idCarrito': vacio ? null : 1,
  'items': vacio
      ? <Object?>[]
      : [
          {
            'idDetalleCarro': 1,
            'idVar': 'v1',
            'sku': 'SKU-1',
            'imagen': null,
            'producto': 'Polera Nike Pro',
            'talla': {'idTalla': 1, 'descripcion': 'M'},
            'colores': [
              {'idColor': 1, 'descripcion': 'Rojo', 'hex': '#FF0000'},
            ],
            'precio': 45,
            'promocion': null,
            'cantidad': 2,
            'subtotal': 90,
            'disponible': true,
            'cantidadDisponible': 4,
          },
        ],
  'cantidadItems': vacio ? 0 : 2,
  'subtotal': vacio ? 0 : 90,
};

Map<String, Object?> reservaJson({String estado = 'confirmada'}) => {
  'nroReserva': 5,
  'fechaReserva': '2026-09-21',
  'horaAtencion': '11:00:00',
  'estado': estado,
  'sucursal': {'nro': 1, 'nombre': 'Central', 'ciudad': 'La Paz'},
  'items': [
    {
      'idDetalleRes': 1,
      'idVar': 'v1',
      'sku': 'SKU-1',
      'producto': 'Polera Nike Pro',
      'cantidad': 2,
      'imagen': null,
      'talla': 'M',
      'categoria': 'Deportiva',
      'colores': ['Rojo'],
    },
  ],
  'totalUnidades': 2,
  'vencida': false,
};

Map<String, Object?> ventaJson({String estado = 'registrada'}) => {
  'nroVenta': 10,
  'fechaHora': '2026-09-19T20:22:00',
  'estado': estado,
  'nit': null,
  'sucursal': {'nro': 1, 'nombre': 'Central', 'ciudad': 'La Paz'},
  'carrito': 1,
  'items': [
    {
      'idDetalleVenta': 1,
      'idVar': 'v1',
      'sku': 'SKU-1',
      'producto': 'Polera Nike Pro',
      'cantidad': 2,
      'precioUnitario': 45,
      'subtotalBruto': 90,
    },
  ],
  'brutoTotal': 90,
  'descAplicado': 9,
  'total': 81,
};

Map<String, Object?> historialJson() => {
  'items': [
    {
      'nroVenta': 10,
      'fechaHora': '2026-09-19T20:22:00',
      'productos': [
        {
          'idVar': 'v1',
          'sku': 'SKU-1',
          'producto': 'Polera Nike Pro',
          'cantidad': 2,
        },
      ],
      'monto': 81,
      'estado': 'registrada',
      'estadoPago': 'aprobado',
    },
  ],
  'total': 1,
  'offset': 0,
  'limit': 20,
  'mensaje': null,
};

/// Instancias ya tipadas, para inyectar en repositorios falsos.
Sesion sesionFalsa() => Sesion.fromJson(_json(sesionJsonBackend()));

ProductoResumen productoFalso({String id = 'p1'}) =>
    ProductoResumen.fromJson(_json(productoJson(id: id)));

ProductoDetalle detalleFalso({String id = 'p1'}) =>
    ProductoDetalle.fromJson(_json(detalleProductoJson(id: id)));

Carrito carritoFalso({bool vacio = false}) =>
    Carrito.fromJson(_json(carritoJson(vacio: vacio)));

Reserva reservaFalsa({String estado = 'confirmada'}) =>
    Reserva.fromJson(_json(reservaJson(estado: estado)));

VentaDetalle ventaFalsa() => VentaDetalle.fromJson(_json(ventaJson()));

PagoDetalle pagoFalso({String estado = 'pendiente', String? checkoutUrl}) =>
    PagoDetalle.fromJson({
      'idPago': 3,
      'metodo': 'tarjeta',
      'monto': 81,
      'estado': estado,
      'fechaHora': '2026-09-19T20:25:00',
      'referencia': 'REF-3',
      'nroVenta': 10,
      'estadoVenta': 'registrada',
      'checkoutUrl': checkoutUrl,
    });

CompraDetalle compraHistorialFalsa() => CompraDetalle.fromJson({
  'nroVenta': 10,
  'fechaHora': '2026-09-19T20:22:00',
  'estado': 'registrada',
  'estadoPago': 'aprobado',
  'nit': null,
  'sucursal': {'nro': 1, 'nombre': 'Central', 'ciudad': 'La Paz'},
  'idCarrito': 1,
  'nroReserva': null,
  'items': [
    {
      'idDetalleVenta': 1,
      'idVar': 'v1',
      'sku': 'SKU-1',
      'producto': 'Polera Nike Pro',
      'cantidad': 2,
      'precioUnitario': 45,
      'subtotalBruto': 90,
    },
  ],
  'brutoTotal': 90,
  'descAplicado': 9,
  'total': 81,
  'pago': {
    'idPago': 3,
    'metodo': 'tarjeta',
    'monto': 81,
    'estado': 'aprobado',
    'fechaHora': '2026-09-19T20:25:00',
    'referencia': 'REF-3',
  },
});

/// Respuesta de sesión con el formato real del backend (usuario/rol/permisos).
Map<String, Object?> sesionJsonBackend({String idUsuario = 'cliente-1'}) => {
  'usuario': {
    'idUsuario': idUsuario,
    'tipo': 'C',
    'nombres': 'Ana Pérez',
    'correo': 'ana@example.com',
  },
  'rol': {'nro': 'cliente', 'descripcion': 'Cliente'},
  'permisos': <String>[],
  'expiraEn': '2030-01-01T00:00:00Z',
};

Map<String, dynamic> _json(Map<String, Object?> data) =>
    data.cast<String, dynamic>();
