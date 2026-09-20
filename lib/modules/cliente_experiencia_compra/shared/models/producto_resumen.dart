/// Modelos de la tarjeta de polera compartida por CU10 (catálogo) y CU17
/// (recomendaciones). El backend vende únicamente poleras, por eso `categoria`
/// representa el MODELO/ESTILO de polera (Deportiva, Semi-Formal, ...).
class CategoriaResumen {
  const CategoriaResumen({required this.idCat, required this.descripcion});

  final int idCat;
  final String descripcion;

  factory CategoriaResumen.fromJson(Map<String, dynamic> json) =>
      CategoriaResumen(
        idCat: json['idCat'] as int? ?? 0,
        descripcion: json['descripcion']?.toString() ?? '',
      );
}

class MarcaResumen {
  const MarcaResumen({required this.idMarca, required this.nombre});

  final int idMarca;
  final String nombre;

  factory MarcaResumen.fromJson(Map<String, dynamic> json) => MarcaResumen(
    idMarca: json['idMarca'] as int? ?? 0,
    nombre: json['nombre']?.toString() ?? '',
  );
}

class ColeccionResumen {
  const ColeccionResumen({required this.idCol, required this.descripcion});

  final int idCol;
  final String descripcion;

  factory ColeccionResumen.fromJson(Map<String, dynamic> json) =>
      ColeccionResumen(
        idCol: json['idCol'] as int? ?? 0,
        descripcion: json['descripcion']?.toString() ?? '',
      );
}

class PromocionResumen {
  const PromocionResumen({
    required this.idPromo,
    required this.nombre,
    required this.tipoDescuento,
    required this.valorDescuento,
  });

  final int idPromo;
  final String nombre;
  final String tipoDescuento;
  final double valorDescuento;

  factory PromocionResumen.fromJson(Map<String, dynamic> json) =>
      PromocionResumen(
        idPromo: json['idPromo'] as int? ?? 0,
        nombre: json['nombre']?.toString() ?? '',
        tipoDescuento: json['tipoDescuento']?.toString() ?? '',
        valorDescuento: _double(json['valorDescuento']),
      );
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

class ProductoResumen {
  const ProductoResumen({
    required this.idProd,
    required this.descripcion,
    required this.categoria,
    required this.marca,
    required this.coleccion,
    required this.disponible,
    required this.totalVariantes,
    this.promocion,
    this.precioMin,
    this.precioMax,
    this.imagen,
  });

  final String idProd;
  final String descripcion;
  final CategoriaResumen categoria;
  final MarcaResumen marca;
  final ColeccionResumen coleccion;
  final PromocionResumen? promocion;
  final double? precioMin;
  final double? precioMax;
  final String? imagen;
  final bool disponible;
  final int totalVariantes;

  factory ProductoResumen.fromJson(
    Map<String, dynamic> json,
  ) => ProductoResumen(
    idProd: json['idProd']?.toString() ?? '',
    descripcion: json['descripcion']?.toString() ?? '',
    categoria: CategoriaResumen.fromJson(
      (json['categoria'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    marca: MarcaResumen.fromJson(
      (json['marca'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    coleccion: ColeccionResumen.fromJson(
      (json['coleccion'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    promocion: json['promocion'] == null
        ? null
        : PromocionResumen.fromJson(
            (json['promocion'] as Map).cast<String, dynamic>(),
          ),
    precioMin: json['precioMin'] == null ? null : _double(json['precioMin']),
    precioMax: json['precioMax'] == null ? null : _double(json['precioMax']),
    imagen: json['imagen']?.toString(),
    disponible: json['disponible'] as bool? ?? false,
    totalVariantes: json['totalVariantes'] as int? ?? 0,
  );
}
