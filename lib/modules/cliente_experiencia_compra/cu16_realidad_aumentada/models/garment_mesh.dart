import 'dart:ui';

import 'garment_vertex.dart';

/// Malla deformable de la polera (CU16): 16 vértices y una triangulación fija.
///
/// La topología (índices) y las coordenadas de textura (UV) están centralizadas
/// aquí: no se recalculan en cada frame, solo cambian las posiciones.
///
/// Esquema de los 16 vértices (siempre en este orden):
///
/// ```text
///   0 cuelloL            1 cuelloR
///         2 hombroL             3 hombroR
///   4 mangaExtL                    7 mangaExtR
///      5 puntaExtL                     8 puntaExtR
///        6 puntaIntL                 9 puntaIntR
///                  10 pechoL  11 pechoR
///                  12 cinturaL 13 cinturaR
///                  14 bordeL  15 bordeR
/// ```
class GarmentMesh {
  const GarmentMesh({required this.vertices, this.indices = triangulos});

  final List<GarmentVertex> vertices;
  final List<int> indices;

  /// Vértices que debe tener cualquier malla válida de CU16.
  static const int totalVertices = 16;

  // Índices con nombre: evitan "números mágicos" al construir la malla.
  static const int cuelloIzq = 0;
  static const int cuelloDer = 1;
  static const int hombroIzq = 2;
  static const int hombroDer = 3;
  static const int mangaExteriorIzq = 4;
  static const int puntaExteriorIzq = 5;
  static const int puntaInteriorIzq = 6;
  static const int mangaExteriorDer = 7;
  static const int puntaExteriorDer = 8;
  static const int puntaInteriorDer = 9;
  static const int pechoIzq = 10;
  static const int pechoDer = 11;
  static const int cinturaIzq = 12;
  static const int cinturaDer = 13;
  static const int bordeIzq = 14;
  static const int bordeDer = 15;

  /// UV por defecto: una polera frontal centrada (cuello arriba, mangas a los
  /// lados, ruedo abajo) medida sobre el bounding box real de la imagen.
  static const List<Offset> uvPorDefecto = [
    Offset(0.43, 0.04), // cuelloL
    Offset(0.57, 0.04), // cuelloR
    Offset(0.26, 0.14), // hombroL
    Offset(0.74, 0.14), // hombroR
    Offset(0.05, 0.21), // mangaExtL
    Offset(0.00, 0.47), // puntaExtL
    Offset(0.15, 0.53), // puntaIntL
    Offset(0.95, 0.21), // mangaExtR
    Offset(1.00, 0.47), // puntaExtR
    Offset(0.85, 0.53), // puntaIntR
    Offset(0.28, 0.46), // pechoL
    Offset(0.72, 0.46), // pechoR
    Offset(0.30, 0.73), // cinturaL
    Offset(0.70, 0.73), // cinturaR
    Offset(0.30, 0.99), // bordeL
    Offset(0.70, 0.99), // bordeR
  ];

  /// Triangulación explícita (14 triángulos). Fija y simétrica: cada mitad del
  /// torso y cada manga están definidas a mano, no por triangulación automática.
  static const List<int> triangulos = [
    // Torso superior (cuello, hombros y pecho).
    cuelloIzq, hombroIzq, pechoIzq, // T1
    cuelloIzq, pechoIzq, pechoDer, // T2
    cuelloIzq, cuelloDer, pechoDer, // T3
    cuelloDer, pechoDer, hombroDer, // T4
    // Manga izquierda.
    hombroIzq, mangaExteriorIzq, puntaExteriorIzq, // T5
    hombroIzq, puntaExteriorIzq, puntaInteriorIzq, // T6
    hombroIzq, puntaInteriorIzq, pechoIzq, // T7 (axila)
    // Manga derecha.
    hombroDer, mangaExteriorDer, puntaExteriorDer, // T8
    hombroDer, puntaExteriorDer, puntaInteriorDer, // T9
    hombroDer, puntaInteriorDer, pechoDer, // T10 (axila)
    // Torso medio e inferior.
    pechoIzq, cinturaIzq, pechoDer, // T11
    pechoDer, cinturaIzq, cinturaDer, // T12
    cinturaIzq, bordeIzq, cinturaDer, // T13
    cinturaDer, bordeIzq, bordeDer, // T14
  ];

  List<Offset> get posiciones => [
    for (final vertice in vertices) vertice.posicion,
  ];

  List<Offset> get coordenadasTextura => [
    for (final vertice in vertices) vertice.uv,
  ];

  /// Comprobaciones obligatorias antes de pintar: tamaño esperado, índices
  /// dentro de rango y coordenadas finitas. Evita dibujar basura si algo falla.
  bool get esValida {
    if (vertices.length != totalVertices) return false;
    if (indices.length % 3 != 0 || indices.isEmpty) return false;
    for (final indice in indices) {
      if (indice < 0 || indice >= vertices.length) return false;
    }
    for (final vertice in vertices) {
      if (!vertice.esFinito) return false;
      if (vertice.uv.dx < 0 ||
          vertice.uv.dx > 1 ||
          vertice.uv.dy < 0 ||
          vertice.uv.dy > 1) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'GarmentMesh(${vertices.length} vértices, ${indices.length ~/ 3} triángulos)';
}
