import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart' show DeviceOrientation;

/// Conversión de coordenadas cámara → pantalla (requirement crítico de CU16).
///
/// Los landmarks vienen en el espacio de la imagen de cámara ROTADA (lo que
/// ML Kit devuelve tras aplicar `InputImageRotation`). El `Canvas` usa el
/// espacio del preview, que puede estar recortado (`BoxFit.cover`) y espejado
/// (cámara frontal). Nunca se debe usar `landmark.x/y` directamente.
class PoseCoordinates {
  PoseCoordinates({
    required this.tamanoFrame,
    required this.tamanoLienzo,
    required this.espejo,
  }) : escala = _escala(tamanoFrame, tamanoLienzo),
       desplazamiento = _desplazamiento(tamanoFrame, tamanoLienzo);

  static double _escala(Size frame, Size lienzo) {
    if (frame.width <= 0 ||
        frame.height <= 0 ||
        lienzo.width <= 0 ||
        lienzo.height <= 0) {
      return 1;
    }
    return math.max(lienzo.width / frame.width, lienzo.height / frame.height);
  }

  static Offset _desplazamiento(Size frame, Size lienzo) {
    final escala = _escala(frame, lienzo);
    return Offset(
      (lienzo.width - frame.width * escala) / 2,
      (lienzo.height - frame.height * escala) / 2,
    );
  }

  /// Imagen de cámara ya rotada (orientación vertical de la persona).
  final Size tamanoFrame;

  /// Tamaño del widget donde se dibuja el preview.
  final Size tamanoLienzo;

  /// `true` con cámara frontal: el preview se ve como un espejo.
  final bool espejo;

  /// Escala de `BoxFit.cover`.
  final double escala;

  /// Centrado del recorte de `BoxFit.cover`.
  final Offset desplazamiento;

  bool get utilizable =>
      tamanoFrame.width > 0 &&
      tamanoFrame.height > 0 &&
      tamanoLienzo.width > 0 &&
      tamanoLienzo.height > 0;

  /// Función ÚNICA de espejo horizontal (no se aplica dos veces).
  static Offset espejoX(Offset punto, double ancho) =>
      Offset(ancho - punto.dx, punto.dy);

  /// Punto de la imagen de cámara → punto del Canvas del preview.
  Offset aLienzo(Offset punto) {
    final conEspejo = espejo ? espejoX(punto, tamanoFrame.width) : punto;
    return Offset(
      conEspejo.dx * escala + desplazamiento.dx,
      conEspejo.dy * escala + desplazamiento.dy,
    );
  }

  /// Igual que [aLienzo] pero sin espejo (para depuración o vista trasera).
  Offset aLienzoSinEspejo(Offset punto) => Offset(
    punto.dx * escala + desplazamiento.dx,
    punto.dy * escala + desplazamiento.dy,
  );

  /// Tamaño de la imagen rotada: 90°/270° intercambian ancho y alto.
  static Size tamanoRotado(Size original, int grados) {
    final normalizado = ((grados % 360) + 360) % 360;
    if (normalizado == 90 || normalizado == 270) {
      return Size(original.height, original.width);
    }
    return original;
  }

  /// Rotación (grados) que se le indica a ML Kit con `InputImageRotation`.
  ///
  /// Sigue la fórmula oficial de ML Kit para Android: se combina la orientación
  /// del sensor con la del dispositivo (la cámara frontal suma, la trasera
  /// resta). Nunca se asume 90° fijo.
  static int gradosParaInputImage({
    required int sensorOrientation,
    required DeviceOrientation dispositivo,
    required bool esFrontal,
  }) {
    final compensacion = switch (dispositivo) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final sensor = ((sensorOrientation % 360) + 360) % 360;
    return esFrontal
        ? (sensor + compensacion) % 360
        : (sensor - compensacion + 360) % 360;
  }

  @override
  String toString() =>
      'PoseCoordinates(frame: $tamanoFrame, lienzo: $tamanoLienzo, '
      'espejo: $espejo, escala: ${escala.toStringAsFixed(3)})';
}
