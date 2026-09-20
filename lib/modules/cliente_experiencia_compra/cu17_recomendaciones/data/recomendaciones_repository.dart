import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../models/recomendacion.dart';

/// CU17 Recomendaciones IA: consume el endpoint del backend.
///
/// La app NO recalcula recomendaciones: el perfil, el puntaje y el fallback los
/// resuelve FastAPI (misma API que usa la web Angular).
class RecomendacionesRepository {
  const RecomendacionesRepository(this._client);

  final ApiClient _client;

  /// `limit` entre 1 y 20 (el backend valida el rango y devuelve 8 por defecto).
  Future<RecomendacionesRespuesta> listar({int limit = 8}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/recomendaciones',
      query: {'limit': limit},
    );
    return RecomendacionesRespuesta.fromJson(response.data ?? const {});
  }
}

final recomendacionesRepositoryProvider = Provider<RecomendacionesRepository>(
  (ref) => RecomendacionesRepository(ref.watch(apiClientProvider)),
);
