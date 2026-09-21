import 'dart:ui';

import '../utils/landmark_helpers.dart';

/// Un punto detectado por ML Kit.
///
/// Las coordenadas ya están en el espacio de la imagen de cámara ROTADA y sin
/// espejar: la conversión a pantalla la hace `PoseCoordinates`.
class PoseLandmark {
  const PoseLandmark({required this.x, required this.y, this.probabilidad = 0});

  final double x;
  final double y;

  /// `likelihood` de ML Kit (`0..1`).
  final double probabilidad;

  Offset get punto => Offset(x, y);

  bool esConfiableCon([double? minimo]) => esConfiable(this, minimo);

  PoseLandmark conOffset(Offset nuevo) =>
      PoseLandmark(x: nuevo.dx, y: nuevo.dy, probabilidad: probabilidad);

  @override
  String toString() =>
      'PoseLandmark(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)} '
      'p=${probabilidad.toStringAsFixed(2)})';
}

/// Frame de pose de CU16: una sola persona, de frente, con el torso visible.
///
/// Se guardan los landmarks que el probador realmente usa. Las muñecas se
/// conservan solo como contexto de orientación del brazo: NO son el extremo de
/// la manga (la manga termina entre hombro y codo).
class PoseFrame {
  const PoseFrame({
    this.hombroIzquierdo,
    this.hombroDerecho,
    this.codoIzquierdo,
    this.codoDerecho,
    this.caderaIzquierda,
    this.caderaDerecha,
    this.munecaIzquierda,
    this.munecaDerecha,
  });

  /// Confianza mínima para considerar un punto utilizable (centralizada).
  static const double confianzaMinima = 0.55;

  final PoseLandmark? hombroIzquierdo;
  final PoseLandmark? hombroDerecho;
  final PoseLandmark? codoIzquierdo;
  final PoseLandmark? codoDerecho;
  final PoseLandmark? caderaIzquierda;
  final PoseLandmark? caderaDerecha;
  final PoseLandmark? munecaIzquierda;
  final PoseLandmark? munecaDerecha;

  /// Puntos obligatorios para dibujar la polera.
  List<PoseLandmark?> get puntosRequeridos => [
    hombroIzquierdo,
    hombroDerecho,
    caderaIzquierda,
    caderaDerecha,
  ];

  bool get hombrosVisibles =>
      esConfiable(hombroIzquierdo) && esConfiable(hombroDerecho);

  bool get caderasVisibles =>
      esConfiable(caderaIzquierda) && esConfiable(caderaDerecha);

  /// Requisito de CU16: sin hombros y caderas confiables no se deforma nada.
  bool get torsoVisible => hombrosVisibles && caderasVisibles;

  // Derivados (ML Kit no entrega cuello ni pecho).

  /// Punto medio de los hombros.
  Offset? get centroCuello =>
      puntoMedio(hombroIzquierdo?.punto, hombroDerecho?.punto);

  /// Punto medio de las caderas.
  Offset? get centroCadera =>
      puntoMedio(caderaIzquierda?.punto, caderaDerecha?.punto);

  /// Pecho: interpolación entre cuello y cadera.
  Offset? get centroPecho => interpolar(centroCuello, centroCadera, 0.45);

  /// Cintura: interpolación entre cuello y cadera.
  Offset? get centroCintura => interpolar(centroCuello, centroCadera, 0.72);

  double? get anchoHombros =>
      distancia(hombroIzquierdo?.punto, hombroDerecho?.punto);

  double? get anchoCaderas =>
      distancia(caderaIzquierda?.punto, caderaDerecha?.punto);

  /// Devuelve una copia reemplazando solo los puntos indicados (usado por el
  /// suavizado, que promedia punto a punto).
  PoseFrame conPuntos({
    PoseLandmark? hombroIzquierdo,
    PoseLandmark? hombroDerecho,
    PoseLandmark? codoIzquierdo,
    PoseLandmark? codoDerecho,
    PoseLandmark? caderaIzquierda,
    PoseLandmark? caderaDerecha,
    PoseLandmark? munecaIzquierda,
    PoseLandmark? munecaDerecha,
  }) => PoseFrame(
    hombroIzquierdo: hombroIzquierdo ?? this.hombroIzquierdo,
    hombroDerecho: hombroDerecho ?? this.hombroDerecho,
    codoIzquierdo: codoIzquierdo ?? this.codoIzquierdo,
    codoDerecho: codoDerecho ?? this.codoDerecho,
    caderaIzquierda: caderaIzquierda ?? this.caderaIzquierda,
    caderaDerecha: caderaDerecha ?? this.caderaDerecha,
    munecaIzquierda: munecaIzquierda ?? this.munecaIzquierda,
    munecaDerecha: munecaDerecha ?? this.munecaDerecha,
  );

  @override
  String toString() =>
      'PoseFrame(torsoVisible: $torsoVisible, hombros: ${hombroIzquierdo != null}'
      '/${hombroDerecho != null}, caderas: ${caderaIzquierda != null}'
      '/${caderaDerecha != null})';
}
