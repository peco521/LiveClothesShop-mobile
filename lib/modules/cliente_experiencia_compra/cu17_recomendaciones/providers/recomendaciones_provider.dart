import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/sesion_provider.dart';
import '../data/recomendaciones_repository.dart';
import '../models/recomendacion.dart';

/// Estado de CU17: la UI reacciona a AsyncLoading / AsyncData / AsyncError.
///
/// Se recalcula al cambiar la sesión (el endpoint exige cliente autenticado).
final recomendacionesProvider = FutureProvider<RecomendacionesRespuesta>((ref) {
  ref.watch(sesionProvider);
  return ref.watch(recomendacionesRepositoryProvider).listar();
});
