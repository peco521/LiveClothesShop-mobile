import 'dart:ui';

/// Vértice de la malla de la polera (CU16).
///
/// [posicion] es el punto en pantalla: cambia en cada frame según la pose.
/// [uv] es la posición FIJA dentro de la textura de la prenda (`0..1` sobre el
/// bounding box real alfa), por eso nunca cambia mientras se prueba una polera.
class GarmentVertex {
  const GarmentVertex({required this.posicion, required this.uv});

  final Offset posicion;
  final Offset uv;

  GarmentVertex conPosicion(Offset nueva) =>
      GarmentVertex(posicion: nueva, uv: uv);

  /// Un vértice con coordenadas no finitas rompería `drawVertices`.
  bool get esFinito =>
      posicion.dx.isFinite &&
      posicion.dy.isFinite &&
      uv.dx.isFinite &&
      uv.dy.isFinite;

  @override
  String toString() => 'GarmentVertex($posicion, uv: $uv)';
}
