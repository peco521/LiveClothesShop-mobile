import 'dart:convert';

import '../models/catalogo.dart';
import '../../../../core/api_client.dart';

/// Acceso a datos CU10 contra /api/catalogo. Solo lectura.
class CatalogoApi {
  final ApiClient _api;
  final String? Function() _credential;

  CatalogoApi({ApiClient? api, required String? Function() credential})
      : _api = api ?? ApiClient(),
        // ignore: prefer_initializing_formals, el parámetro es público entre paquetes
        _credential = credential;

  Future<ProductosListado> listar(CatalogoFiltros filtros, {int offset = 0, int limit = 20}) async {
    final response = await _api.getRaw('/api/catalogo/productos',
        query: filtros.toQuery(offset, limit), credential: _credential());
    return ProductosListado.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProductoDetalle> detalle(String idProd) async {
    final response = await _api.getRaw('/api/catalogo/productos/${Uri.encodeComponent(idProd)}',
        credential: _credential());
    return ProductoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<FacetaItem>> faceta(String grupo) async {
    final response = await _api.getRaw('/api/catalogo/$grupo', credential: _credential());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['items'] as List).map((e) => FacetaItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
