import '../../shared/models/producto_resumen.dart';

/// Faceta de filtro del catálogo (`/api/catalogo/{grupo}`).
class FacetaItem {
  const FacetaItem({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory FacetaItem.fromJson(Map<String, dynamic> json) => FacetaItem(
    id: json['id'] as int? ?? 0,
    nombre: json['nombre']?.toString() ?? '',
  );
}

class TallaDetalle {
  const TallaDetalle({required this.idTalla, required this.descripcion});

  final int idTalla;
  final String descripcion;

  factory TallaDetalle.fromJson(Map<String, dynamic> json) => TallaDetalle(
    idTalla: json['idTalla'] as int? ?? 0,
    descripcion: json['descripcion']?.toString() ?? '',
  );
}

class ColorDetalle {
  const ColorDetalle({
    required this.idColor,
    required this.descripcion,
    required this.hex,
  });

  final int idColor;
  final String descripcion;
  final String hex;

  factory ColorDetalle.fromJson(Map<String, dynamic> json) => ColorDetalle(
    idColor: json['idColor'] as int? ?? 0,
    descripcion: json['descripcion']?.toString() ?? '',
    hex: json['hex']?.toString() ?? '#000000',
  );
}

/// Variante (talla + colores) de una polera.
class VarianteDetalle {
  const VarianteDetalle({
    required this.idVariante,
    required this.sku,
    required this.precio,
    required this.talla,
    this.imagen,
    this.colores = const [],
  });

  final String idVariante;
  final String sku;
  final double precio;
  final String? imagen;
  final TallaDetalle talla;
  final List<ColorDetalle> colores;

  factory VarianteDetalle.fromJson(Map<String, dynamic> json) =>
      VarianteDetalle(
        idVariante: json['idVariante']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        precio: _numero(json['precio']),
        imagen: json['imagen']?.toString(),
        talla: TallaDetalle.fromJson(
          (json['talla'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        colores: (json['colores'] as List? ?? const [])
            .map(
              (item) =>
                  ColorDetalle.fromJson((item as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
}

/// Existencias de una variante en una sucursal concreta.
class DisponibilidadSucursal {
  const DisponibilidadSucursal({
    required this.nroSuc,
    required this.sucursal,
    required this.ciudad,
    required this.idVariante,
    required this.stock,
    required this.cantDisp,
  });

  final int nroSuc;
  final String sucursal;
  final String ciudad;
  final String idVariante;
  final int stock;
  final int cantDisp;

  factory DisponibilidadSucursal.fromJson(Map<String, dynamic> json) =>
      DisponibilidadSucursal(
        nroSuc: json['nroSuc'] as int? ?? 0,
        sucursal: json['sucursal']?.toString() ?? '',
        ciudad: json['ciudad']?.toString() ?? '',
        idVariante: json['idVariante']?.toString() ?? '',
        stock: json['stock'] as int? ?? 0,
        cantDisp: json['cantDisp'] as int? ?? 0,
      );
}

/// Detalle de polera del catálogo (`/api/catalogo/productos/{idProd}`).
class ProductoDetalle {
  const ProductoDetalle({
    required this.idProd,
    required this.descripcion,
    required this.estado,
    required this.categoria,
    required this.marca,
    required this.coleccion,
    this.promocion,
    this.variantes = const [],
    this.disponibilidad = const [],
  });

  final String idProd;
  final String descripcion;
  final String estado;
  final CategoriaResumen categoria;
  final MarcaResumen marca;
  final ColeccionResumen coleccion;
  final PromocionResumen? promocion;
  final List<VarianteDetalle> variantes;
  final List<DisponibilidadSucursal> disponibilidad;

  List<DisponibilidadSucursal> sucursalesDe(String idVariante) =>
      disponibilidad.where((row) => row.idVariante == idVariante).toList();

  int stockDe(String idVariante) => sucursalesDe(
    idVariante,
  ).fold<int>(0, (total, row) => total + (row.cantDisp > 0 ? row.cantDisp : 0));

  bool disponibleEn(String idVariante) => stockDe(idVariante) > 0;

  factory ProductoDetalle.fromJson(Map<String, dynamic> json) =>
      ProductoDetalle(
        idProd: json['idProd']?.toString() ?? '',
        descripcion: json['descripcion']?.toString() ?? '',
        estado: json['estado']?.toString() ?? '',
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
        variantes: (json['variantes'] as List? ?? const [])
            .map(
              (item) => VarianteDetalle.fromJson(
                (item as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        disponibilidad: (json['disponibilidad'] as List? ?? const [])
            .map(
              (item) => DisponibilidadSucursal.fromJson(
                (item as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );
}

double _numero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
