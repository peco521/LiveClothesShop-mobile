import '../../shared/models/producto_resumen.dart';

/// CU17 Recibir recomendaciones IA.
///
/// El backend calcula todo (perfil + puntaje): la app solo muestra el resultado.
/// `RecomendacionItem` extiende la tarjeta de CU10 con `score` y `razones`, tal
/// como el contrato real de `/api/cliente/recomendaciones`.
class RecomendacionItem {
  const RecomendacionItem({
    required this.producto,
    required this.score,
    this.razones = const [],
  });

  final ProductoResumen producto;
  final int score;
  final List<String> razones;

  factory RecomendacionItem.fromJson(Map<String, dynamic> json) =>
      RecomendacionItem(
        producto: ProductoResumen.fromJson(json),
        score: json['score'] as int? ?? 0,
        razones: (json['razones'] as List? ?? const [])
            .map((razon) => razon.toString())
            .where((razon) => razon.isNotEmpty)
            .toList(),
      );
}

class RecomendacionesRespuesta {
  const RecomendacionesRespuesta({
    required this.tipo,
    required this.mensaje,
    this.total = 0,
    this.items = const [],
  });

  /// `personalizada` cuando el backend encontró perfil; `general` en el fallback.
  final String tipo;
  final String mensaje;
  final int total;
  final List<RecomendacionItem> items;

  bool get esPersonalizada => tipo == 'personalizada';

  factory RecomendacionesRespuesta.fromJson(Map<String, dynamic> json) =>
      RecomendacionesRespuesta(
        tipo: json['tipo']?.toString() ?? 'general',
        mensaje: json['mensaje']?.toString() ?? '',
        total: json['total'] as int? ?? 0,
        items: (json['items'] as List? ?? const [])
            .map(
              (item) => RecomendacionItem.fromJson(
                (item as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );
}
