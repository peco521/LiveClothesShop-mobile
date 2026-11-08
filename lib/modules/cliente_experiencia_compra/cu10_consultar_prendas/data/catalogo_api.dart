import 'dart:convert';

import '../models/catalogo.dart';
import '../../../../core/api_client.dart';
import '../../../../core/api_error.dart';
import '../../../../core/catalog_repository.dart';

/// Acceso a datos CU10 contra /api/catalogo. Solo lectura.
class CatalogoApi {
  final ApiClient _api;
  final String? Function() _credential;
  final CatalogRepository? repository;
  final String? tenant;
  final String? user;
  CatalogSnapshot? lastSnapshot;
  bool get usingOffline => lastSnapshot != null;

  CatalogoApi({ApiClient? api, required String? Function() credential,
      this.repository, this.tenant, this.user})
      : _api = api ?? ApiClient(),
        // ignore: prefer_initializing_formals, el parámetro es público entre paquetes
        _credential = credential;

  Future<ProductosListado> listar(CatalogoFiltros filtros, {int offset = 0, int limit = 20}) async {
    final query = filtros.toQuery(offset, limit);
    final body = await _read('/api/catalogo/productos', _pageKey(query), query: query);
    return ProductosListado.fromJson(body);
  }

  Future<ProductoDetalle> detalle(String idProd) async {
    final body = await _read('/api/catalogo/productos/${Uri.encodeComponent(idProd)}', 'detail:$idProd');
    return ProductoDetalle.fromJson(body);
  }

  Future<List<FacetaItem>> faceta(String grupo) async {
    final body = await _read('/api/catalogo/$grupo', 'facet:$grupo');
    return (body['items'] as List).map((e) => FacetaItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _pageKey(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    return 'page:${jsonEncode({for (final key in keys) key: query[key]})}';
  }

  Future<Map<String, dynamic>> _read(String path, String key, {Map<String, String>? query}) async {
    try {
      final response = await _api.getRaw(path, query: query, credential: _credential());
      lastSnapshot = null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiException catch (error) {
      // A revoked/forbidden session must never be masked by local data.
      if (error.status != 0 && error.status < 500) rethrow;
      if (repository == null || tenant == null || user == null) rethrow;
      final saved = await repository!.read(tenant!, user!, key);
      if (saved == null) rethrow;
      lastSnapshot = saved;
      return saved.data;
    }
  }

  /// Explicit bounded download: first 20 products matching the current filters,
  /// their variants/branches and facets; no partial writes if any request fails.
  Future<int> descargar(CatalogoFiltros filtros) async {
    if (repository == null || tenant == null || user == null) {
      throw StateError('Se requiere un propietario para descargar el catálogo');
    }
    final credential = _credential();
    final query = filtros.toQuery(0, 20);
    final response = await _api.getRaw('/api/catalogo/productos', query: query, credential: credential);
    final page = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = ProductosListado.fromJson(page);
    final details = <Map<String, dynamic>>[];
    for (final item in parsed.items) {
      final response = await _api.getRaw('/api/catalogo/productos/${Uri.encodeComponent(item.idProd)}', credential: credential);
      final detail = jsonDecode(response.body) as Map<String, dynamic>;
      ProductoDetalle.fromJson(detail); // Validate the full subset before committing.
      details.add(detail);
    }
    final facets = <String, Map<String, dynamic>>{};
    for (final group in ['categorias', 'marcas', 'colecciones', 'temporadas', 'tallas', 'colores']) {
      final response = await _api.getRaw('/api/catalogo/$group', credential: credential);
      facets[group] = jsonDecode(response.body) as Map<String, dynamic>;
    }
    await repository!.saveSubset(tenant: tenant!, user: user!, pageKey: _pageKey(query),
      page: {...page, 'total': parsed.items.length}, details: details, facets: facets);
    return parsed.items.length;
  }
}
