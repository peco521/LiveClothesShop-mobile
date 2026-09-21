import 'dart:math' as math;
import 'dart:ui';

import '../models/pose_frame.dart';

/// Aritmética de landmarks reutilizable por CU16.
///
/// Aquí no hay cámara ni ML Kit: son funciones puras, fáciles de probar sin
/// dispositivo. Todas reciben y devuelven `Offset` (o `null` si falta un punto).
Offset? puntoMedio(Offset? a, Offset? b) {
  if (a == null || b == null) return null;
  return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

/// Interpolación lineal: `t = 0` devuelve [a] y `t = 1` devuelve [b].
Offset? interpolar(Offset? a, Offset? b, double t) {
  if (a == null || b == null) return null;
  return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
}

/// Interpolación segura para matrices de `Offset` obligatorios.
Offset interpolarPunto(Offset a, Offset b, double t) =>
    Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

double? distancia(Offset? a, Offset? b) {
  if (a == null || b == null) return null;
  return (b - a).distance;
}

/// Dirección unitaria de [desde] hacia [hacia]; `null` si son el mismo punto.
Offset? direccionUnitaria(Offset? desde, Offset? hacia) {
  if (desde == null || hacia == null) return null;
  final delta = hacia - desde;
  final largo = delta.distance;
  if (largo < 0.0001) return null;
  return delta / largo;
}

/// Perpendicular unitaria (rotación de 90°): sirve para dar ancho a las mangas.
Offset perpendicularUnitaria(Offset vector) {
  final largo = vector.distance;
  if (largo < 0.0001) return const Offset(0, 1);
  return Offset(-vector.dy / largo, vector.dx / largo);
}

/// Un punto a [largo] de distancia en la dirección [direccion].
Offset avanzar(Offset origen, Offset direccion, double largo) =>
    Offset(origen.dx + direccion.dx * largo, origen.dy + direccion.dy * largo);

/// Escala un punto respecto de un centro (el ancho del torso, por ejemplo).
Offset escalarDesde(Offset centro, Offset punto, double factor) => Offset(
  centro.dx + (punto.dx - centro.dx) * factor,
  centro.dy + (punto.dy - centro.dy) * factor,
);

/// Proyecta [punto] sobre el eje definido por [origen] y [eje] (unitario).
double proyeccionSobre(Offset punto, Offset origen, Offset eje) {
  final delta = punto - origen;
  return delta.dx * eje.dx + delta.dy * eje.dy;
}

/// Landmark confiable: existe y supera el umbral de confianza de CU16.
bool esConfiable(PoseLandmark? landmark, [double? minimo]) =>
    landmark != null &&
    landmark.probabilidad >= (minimo ?? PoseFrame.confianzaMinima);

/// Ángulo (radianes) del eje hombro→hombro respecto de la horizontal.
double anguloHombros(Offset? izquierdo, Offset? derecho) {
  if (izquierdo == null || derecho == null) return 0;
  return math.atan2(derecho.dy - izquierdo.dy, derecho.dx - izquierdo.dx);
}
