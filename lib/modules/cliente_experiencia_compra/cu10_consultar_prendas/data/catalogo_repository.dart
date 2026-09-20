import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../../shared/models/producto_resumen.dart';
import '../models/producto.dart';

/// Filtros del catálogo: mismo contrato que `/api/catalogo/productos`.
class FiltrosCatalogo {
  const FiltrosCatalogo({
    this.q = '',
    this.idCat,
    this.idMarca,
    this.idTemp,
    this.idTalla,
    this.minPrecio,
    this.maxPrecio,
    this.soloDisponibles = false,
    this.sort = 'nombre_asc',
    this.offset = 0,
    this.limit = 20,
  });

  final String q;
  final int? idCat;
  final int? idMarca;
  final int? idTemp;
  final int? idTalla;
  final double? minPrecio;
  final double? maxPrecio;
  final bool soloDisponibles;
  final String sort;
  final int offset;
  final int limit;

  FiltrosCatalogo copyWith({
    String? q,
    int? idCat,
    int? idMarca,
    int? idTemp,
    int? idTalla,
    double? minPrecio,
    double? maxPrecio,
    bool? soloDisponibles,
    String? sort,
    int? offset,
    int? limit,
    bool limpiarModelo = false,
    bool limpiarMarca = false,
    bool limpiarTemporada = false,
    bool limpiarTalla = false,
    bool limpiarPrecios = false,
  }) {
    return FiltrosCatalogo(
      q: q ?? this.q,
      idCat: limpiarModelo ? null : (idCat ?? this.idCat),
      idMarca: limpiarMarca ? null : (idMarca ?? this.idMarca),
      idTemp: limpiarTemporada ? null : (idTemp ?? this.idTemp),
      idTalla: limpiarTalla ? null : (idTalla ?? this.idTalla),
      minPrecio: limpiarPrecios ? null : (minPrecio ?? this.minPrecio),
      maxPrecio: limpiarPrecios ? null : (maxPrecio ?? this.maxPrecio),
      soloDisponibles: soloDisponibles ?? this.soloDisponibles,
      sort: sort ?? this.sort,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toQuery() => {
    'offset': offset,
    'limit': limit,
    'sort': sort,
    if (q.trim().isNotEmpty) 'q': q.trim(),
    if (idCat != null) 'idCat': idCat,
    if (idMarca != null) 'idMarca': idMarca,
    if (idTemp != null) 'idTemp': idTemp,
    if (idTalla != null) 'idTalla': idTalla,
    if (minPrecio != null) 'minPrecio': minPrecio,
    if (maxPrecio != null) 'maxPrecio': maxPrecio,
    if (soloDisponibles) 'soloDisponibles': true,
  };
}

class ProductosCatalogo {
  const ProductosCatalogo({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<ProductoResumen> items;
  final int total;
  final int offset;
  final int limit;
}

/// Facetas de referencia para los filtros (modelo/marca/temporada/talla).
class FacetasCatalogo {
  const FacetasCatalogo({
    this.modelos = const [],
    this.marcas = const [],
    this.temporadas = const [],
    this.tallas = const [],
  });

  final List<FacetaItem> modelos;
  final List<FacetaItem> marcas;
  final List<FacetaItem> temporadas;
  final List<FacetaItem> tallas;
}

/// CU10 Consultar prendas: mismo backend que la web, sin lógica duplicada.
class CatalogoRepository {
  const CatalogoRepository(this._client);

  final ApiClient _client;

  Future<ProductosCatalogo> listar(FiltrosCatalogo filtros) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/catalogo/productos',
      query: filtros.toQuery(),
    );
    final data = response.data ?? const <String, dynamic>{};
    final items = (data['items'] as List? ?? const [])
        .map(
          (item) =>
              ProductoResumen.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
    return ProductosCatalogo(
      items: items,
      total: data['total'] as int? ?? items.length,
      offset: data['offset'] as int? ?? filtros.offset,
      limit: data['limit'] as int? ?? filtros.limit,
    );
  }

  Future<ProductoDetalle> detalle(String idProd) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/catalogo/productos/${Uri.encodeComponent(idProd)}',
    );
    return ProductoDetalle.fromJson(response.data ?? const {});
  }

  Future<List<FacetaItem>> faceta(String grupo) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/catalogo/$grupo',
    );
    final data = response.data ?? const <String, dynamic>{};
    return (data['items'] as List? ?? const [])
        .map(
          (item) => FacetaItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// Carga en paralelo las facetas que usa la hoja de filtros (sin N+1 por prenda).
  Future<FacetasCatalogo> facetas() async {
    final resultados = await Future.wait([
      faceta('categorias'),
      faceta('marcas'),
      faceta('temporadas'),
      faceta('tallas'),
    ]);
    return FacetasCatalogo(
      modelos: resultados[0],
      marcas: resultados[1],
      temporadas: resultados[2],
      tallas: resultados[3],
    );
  }
}

final catalogoRepositoryProvider = Provider<CatalogoRepository>(
  (ref) => CatalogoRepository(ref.watch(apiClientProvider)),
);
