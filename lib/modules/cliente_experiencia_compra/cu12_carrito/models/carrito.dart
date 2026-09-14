// Modelos CU12: reflejan el JSON de /api/cliente/carrito sin inventar atributos.

class CarritoItem {
  final int idDetalle;
  final String idVar;
  final String sku;
  final String? imagen;
  final String producto;
  final String talla;
  final List<String> colores;
  final double precio;
  final String? promocion;
  final int cantidad;
  final double subtotal;
  final bool disponible;
  final int cantidadDisponible;

  const CarritoItem({
    required this.idDetalle,
    required this.idVar,
    required this.sku,
    required this.imagen,
    required this.producto,
    required this.talla,
    required this.colores,
    required this.precio,
    required this.promocion,
    required this.cantidad,
    required this.subtotal,
    required this.disponible,
    required this.cantidadDisponible,
  });

  static double _numero(dynamic value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  factory CarritoItem.fromJson(Map<String, dynamic> json) {
    final talla = json['talla'] as Map<String, dynamic>;
    final promo = json['promocion'] as Map<String, dynamic>?;
    return CarritoItem(
      idDetalle: (json['idDetalleCarro'] as num).toInt(),
      idVar: json['idVar'] as String,
      sku: json['sku'] as String,
      imagen: json['imagen'] as String?,
      producto: json['producto'] as String,
      talla: talla['descripcion'] as String,
      colores: ((json['colores'] as List? ?? []).map((e) => (e as Map<String, dynamic>)['descripcion'] as String)).toList(),
      precio: _numero(json['precio']),
      promocion: promo?['nombre'] as String?,
      cantidad: (json['cantidad'] as num).toInt(),
      subtotal: _numero(json['subtotal']),
      disponible: json['disponible'] as bool,
      cantidadDisponible: (json['cantidadDisponible'] as num).toInt(),
    );
  }
}

class CarritoDetalle {
  final int? idCarrito;
  final List<CarritoItem> items;
  final int cantidadItems;
  final double subtotal;

  const CarritoDetalle({
    required this.idCarrito,
    required this.items,
    required this.cantidadItems,
    required this.subtotal,
  });

  bool get vacio => items.isEmpty;

  factory CarritoDetalle.fromJson(Map<String, dynamic> json) => CarritoDetalle(
        idCarrito: (json['idCarrito'] as num?)?.toInt(),
        items: ((json['items'] as List? ?? []).map((e) => CarritoItem.fromJson(e as Map<String, dynamic>))).toList(),
        cantidadItems: (json['cantidadItems'] as num).toInt(),
        subtotal: json['subtotal'] is num
            ? (json['subtotal'] as num).toDouble()
            : double.parse(json['subtotal'].toString()),
      );

  factory CarritoDetalle.vacio() =>
      const CarritoDetalle(idCarrito: null, items: [], cantidadItems: 0, subtotal: 0);
}
