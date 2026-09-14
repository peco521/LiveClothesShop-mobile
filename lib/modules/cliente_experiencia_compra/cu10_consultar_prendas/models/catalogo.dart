// Modelos CU10: reflejan el JSON de /api/catalogo sin inventar atributos.

class FacetaItem {
  final int id;
  final String nombre;

  const FacetaItem({required this.id, required this.nombre});

  factory FacetaItem.fromJson(Map<String, dynamic> json) =>
      FacetaItem(id: (json['id'] as num).toInt(), nombre: json['nombre'] as String);
}

class CatalogoResumen {
  final String id;
  final String descripcion;
  final String marca;
  final String categoria;

  const CatalogoResumen({required this.id, required this.descripcion, required this.marca, required this.categoria});
}

class ProductoResumen {
  final String idProd;
  final String descripcion;
  final String categoria;
  final String marca;
  final String coleccion;
  final String? promocion;
  final double? precioMin;
  final double? precioMax;
  final String? imagen;
  final bool disponible;
  final int totalVariantes;

  const ProductoResumen({
    required this.idProd,
    required this.descripcion,
    required this.categoria,
    required this.marca,
    required this.coleccion,
    required this.promocion,
    required this.precioMin,
    required this.precioMax,
    required this.imagen,
    required this.disponible,
    required this.totalVariantes,
  });

  static double? _precio(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory ProductoResumen.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map<String, dynamic>;
    final marca = json['marca'] as Map<String, dynamic>;
    final coleccion = json['coleccion'] as Map<String, dynamic>;
    final promo = json['promocion'] as Map<String, dynamic>?;
    return ProductoResumen(
      idProd: json['idProd'] as String,
      descripcion: json['descripcion'] as String,
      categoria: categoria['descripcion'] as String,
      marca: marca['nombre'] as String,
      coleccion: coleccion['descripcion'] as String,
      promocion: promo?['nombre'] as String?,
      precioMin: _precio(json['precioMin']),
      precioMax: _precio(json['precioMax']),
      imagen: json['imagen'] as String?,
      disponible: json['disponible'] as bool,
      totalVariantes: (json['totalVariantes'] as num).toInt(),
    );
  }

  String get precioTexto {
    if (precioMin == null) return 'Precio a consultar';
    if (precioMax == null || precioMax == precioMin) return 'Bs ${precioMin!.toStringAsFixed(2)}';
    return 'Bs ${precioMin!.toStringAsFixed(2)} – ${precioMax!.toStringAsFixed(2)}';
  }
}

class ProductosListado {
  final List<ProductoResumen> items;
  final int total;
  final int offset;
  final int limit;

  const ProductosListado({required this.items, required this.total, required this.offset, required this.limit});

  factory ProductosListado.fromJson(Map<String, dynamic> json) => ProductosListado(
        items: (json['items'] as List).map((e) => ProductoResumen.fromJson(e as Map<String, dynamic>)).toList(),
        total: (json['total'] as num).toInt(),
        offset: (json['offset'] as num).toInt(),
        limit: (json['limit'] as num).toInt(),
      );
}

class TallaDetalle {
  final int id;
  final String descripcion;

  const TallaDetalle({required this.id, required this.descripcion});

  factory TallaDetalle.fromJson(Map<String, dynamic> json) =>
      TallaDetalle(id: (json['idTalla'] as num).toInt(), descripcion: json['descripcion'] as String);
}

class ColorDetalle {
  final int id;
  final String descripcion;
  final String hex;

  const ColorDetalle({required this.id, required this.descripcion, required this.hex});

  factory ColorDetalle.fromJson(Map<String, dynamic> json) => ColorDetalle(
        id: (json['idColor'] as num).toInt(),
        descripcion: json['descripcion'] as String,
        hex: json['hex'] as String,
      );
}

class VarianteDetalle {
  final String id;
  final String sku;
  final double precio;
  final String? imagen;
  final TallaDetalle talla;
  final List<ColorDetalle> colores;

  const VarianteDetalle({
    required this.id,
    required this.sku,
    required this.precio,
    required this.imagen,
    required this.talla,
    required this.colores,
  });

  factory VarianteDetalle.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    return VarianteDetalle(
      id: json['idVariante'] as String,
      sku: json['sku'] as String,
      precio: precio is num ? precio.toDouble() : double.parse(precio.toString()),
      imagen: json['imagen'] as String?,
      talla: TallaDetalle.fromJson(json['talla'] as Map<String, dynamic>),
      colores: ((json['colores'] as List? ?? []).map((e) => ColorDetalle.fromJson(e as Map<String, dynamic>))).toList(),
    );
  }
}

class DisponibilidadSucursal {
  final int nroSuc;
  final String sucursal;
  final String ciudad;
  final String idVariante;
  final int stock;
  final int cantDisp;

  const DisponibilidadSucursal({
    required this.nroSuc,
    required this.sucursal,
    required this.ciudad,
    required this.idVariante,
    required this.stock,
    required this.cantDisp,
  });

  factory DisponibilidadSucursal.fromJson(Map<String, dynamic> json) => DisponibilidadSucursal(
        nroSuc: (json['nroSuc'] as num).toInt(),
        sucursal: json['sucursal'] as String,
        ciudad: json['ciudad'] as String,
        idVariante: json['idVariante'] as String,
        stock: (json['stock'] as num).toInt(),
        cantDisp: (json['cantDisp'] as num).toInt(),
      );
}

class ProductoDetalle {
  final String idProd;
  final String descripcion;
  final String marca;
  final String categoria;
  final String coleccion;
  final String? promocion;
  final List<VarianteDetalle> variantes;
  final List<DisponibilidadSucursal> disponibilidad;

  const ProductoDetalle({
    required this.idProd,
    required this.descripcion,
    required this.marca,
    required this.categoria,
    required this.coleccion,
    required this.promocion,
    required this.variantes,
    required this.disponibilidad,
  });

  factory ProductoDetalle.fromJson(Map<String, dynamic> json) {
    final marca = json['marca'] as Map<String, dynamic>;
    final categoria = json['categoria'] as Map<String, dynamic>;
    final coleccion = json['coleccion'] as Map<String, dynamic>;
    final promo = json['promocion'] as Map<String, dynamic>?;
    return ProductoDetalle(
      idProd: json['idProd'] as String,
      descripcion: json['descripcion'] as String,
      marca: marca['nombre'] as String,
      categoria: categoria['descripcion'] as String,
      coleccion: coleccion['descripcion'] as String,
      promocion: promo?['nombre'] as String?,
      variantes: ((json['variantes'] as List? ?? []).map((e) => VarianteDetalle.fromJson(e as Map<String, dynamic>))).toList(),
      disponibilidad: ((json['disponibilidad'] as List? ?? []).map((e) => DisponibilidadSucursal.fromJson(e as Map<String, dynamic>))).toList(),
    );
  }

  List<DisponibilidadSucursal> disponibilidadDe(String idVariante) =>
      disponibilidad.where((e) => e.idVariante == idVariante).toList();
}

/// Filtros del catálogo (solo claves soportadas por GET /api/catalogo/productos).
class CatalogoFiltros {
  final String q;
  final int? categoria;
  final int? marca;
  final int? coleccion;
  final int? temporada;
  final int? talla;
  final int? color;
  final double? minPrecio;
  final double? maxPrecio;
  final bool soloDisponibles;
  final String sort;

  const CatalogoFiltros({
    this.q = '',
    this.categoria,
    this.marca,
    this.coleccion,
    this.temporada,
    this.talla,
    this.color,
    this.minPrecio,
    this.maxPrecio,
    this.soloDisponibles = false,
    this.sort = 'nombre_asc',
  });

  Map<String, String> toQuery(int offset, int limit) {
    final query = <String, String>{'offset': '$offset', 'limit': '$limit'};
    if (q.trim().isNotEmpty) query['q'] = q.trim();
    if (categoria != null) query['idCat'] = '$categoria';
    if (marca != null) query['idMarca'] = '$marca';
    if (coleccion != null) query['idCol'] = '$coleccion';
    if (temporada != null) query['idTemp'] = '$temporada';
    if (talla != null) query['idTalla'] = '$talla';
    if (color != null) query['idColor'] = '$color';
    if (minPrecio != null) query['minPrecio'] = '$minPrecio';
    if (maxPrecio != null) query['maxPrecio'] = '$maxPrecio';
    if (soloDisponibles) query['soloDisponibles'] = 'true';
    query['sort'] = sort;
    return query;
  }
}
