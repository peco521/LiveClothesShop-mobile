import '../../shared/models/producto_resumen.dart';

/// Ítem del carrito (`/api/cliente/carrito`), con la promoción aplicada por el
/// backend: el subtotal que llega ya es el valor real, la app solo lo muestra.
class CarritoItem {
  const CarritoItem({
    required this.idDetalleCarro,
    required this.idVar,
    required this.sku,
    required this.producto,
    required this.talla,
    required this.precio,
    required this.cantidad,
    required this.subtotal,
    required this.disponible,
    required this.cantidadDisponible,
    this.imagen,
    this.promocion,
    this.colores = const [],
  });

  final int idDetalleCarro;
  final String idVar;
  final String sku;
  final String producto;
  final String? imagen;
  final TallaCarrito talla;
  final List<String> colores;
  final double precio;
  final PromocionResumen? promocion;
  final int cantidad;
  final double subtotal;
  final bool disponible;
  final int cantidadDisponible;

  factory CarritoItem.fromJson(Map<String, dynamic> json) => CarritoItem(
    idDetalleCarro: json['idDetalleCarro'] as int? ?? 0,
    idVar: json['idVar']?.toString() ?? '',
    sku: json['sku']?.toString() ?? '',
    producto: json['producto']?.toString() ?? '',
    imagen: json['imagen']?.toString(),
    talla: TallaCarrito.fromJson(
      (json['talla'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    colores: (json['colores'] as List? ?? const [])
        .map((item) => (item as Map)['descripcion']?.toString() ?? '')
        .where((nombre) => nombre.isNotEmpty)
        .toList(),
    precio: _numero(json['precio']),
    promocion: json['promocion'] == null
        ? null
        : PromocionResumen.fromJson(
            (json['promocion'] as Map).cast<String, dynamic>(),
          ),
    cantidad: json['cantidad'] as int? ?? 0,
    subtotal: _numero(json['subtotal']),
    disponible: json['disponible'] as bool? ?? false,
    cantidadDisponible: json['cantidadDisponible'] as int? ?? 0,
  );
}

class TallaCarrito {
  const TallaCarrito({required this.idTalla, required this.descripcion});

  final int idTalla;
  final String descripcion;

  factory TallaCarrito.fromJson(Map<String, dynamic> json) => TallaCarrito(
    idTalla: json['idTalla'] as int? ?? 0,
    descripcion: json['descripcion']?.toString() ?? '',
  );
}

class Carrito {
  const Carrito({
    this.idCarrito,
    this.items = const [],
    this.cantidadItems = 0,
    this.subtotal = 0,
  });

  final int? idCarrito;
  final List<CarritoItem> items;
  final int cantidadItems;
  final double subtotal;

  bool get vacio => items.isEmpty;

  factory Carrito.fromJson(Map<String, dynamic> json) => Carrito(
    idCarrito: json['idCarrito'] as int?,
    items: (json['items'] as List? ?? const [])
        .map(
          (item) => CarritoItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
    cantidadItems: json['cantidadItems'] as int? ?? 0,
    subtotal: _numero(json['subtotal']),
  );
}

double _numero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
