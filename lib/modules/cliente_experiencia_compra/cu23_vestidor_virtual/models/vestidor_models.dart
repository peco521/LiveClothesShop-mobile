import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estado de seguimiento del vestidor virtual.
enum FittingTrackingStatus {
  iniciando,
  sinPermiso,
  camaraNoDisponible,
  buscandoPersona,
  cuerpoDetectado,
  errorSensor,
}

/// Estimación de los puntos anatómicos del cuerpo para anclaje de prendas.
class BodyPoseEstimate {
  final Offset? leftShoulder;
  final Offset? rightShoulder;
  final Offset? leftHip;
  final Offset? rightHip;
  final Offset? nose;
  final double confidence;

  const BodyPoseEstimate({
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
    this.nose,
    this.confidence = 0.0,
  });

  bool get hasTorso =>
      leftShoulder != null &&
      rightShoulder != null &&
      leftHip != null &&
      rightHip != null;

  bool get hasShoulders => leftShoulder != null && rightShoulder != null;

  /// Punto medio entre ambos hombros (anclaje superior del cuello).
  Offset? get shoulderMidpoint {
    if (!hasShoulders) return null;
    return Offset(
      (leftShoulder!.dx + rightShoulder!.dx) / 2.0,
      (leftShoulder!.dy + rightShoulder!.dy) / 2.0,
    );
  }

  /// Punto medio entre ambas caderas (anclaje inferior del torso).
  Offset? get hipMidpoint {
    if (leftHip == null || rightHip == null) return null;
    return Offset(
      (leftHip!.dx + rightHip!.dx) / 2.0,
      (leftHip!.dy + rightHip!.dy) / 2.0,
    );
  }

  /// Distancia euclidiana entre hombros en píxeles de imagen.
  double? get shoulderWidth {
    if (!hasShoulders) return null;
    final dx = rightShoulder!.dx - leftShoulder!.dx;
    final dy = rightShoulder!.dy - leftShoulder!.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Altura aproximada del torso (desde punto medio de hombros al de caderas).
  double? get torsoHeight {
    final sMid = shoulderMidpoint;
    final hMid = hipMidpoint;
    if (sMid == null || hMid == null) return null;
    final dx = hMid.dx - sMid.dx;
    final dy = hMid.dy - sMid.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Ángulo de inclinación de los hombros en radianes.
  double get rotationAngle {
    if (!hasShoulders) return 0.0;
    return math.atan2(
      rightShoulder!.dy - leftShoulder!.dy,
      rightShoulder!.dx - leftShoulder!.dx,
    );
  }

  /// Suaviza la transición entre dos poses sucesivas mediante EMA (Exponential Moving Average).
  BodyPoseEstimate smoothWith(BodyPoseEstimate? previous, {double alpha = 0.65}) {
    if (previous == null) return this;
    Offset? lerpOffset(Offset? current, Offset? prev) {
      if (current == null) return prev;
      if (prev == null) return current;
      return Offset(
        prev.dx + (current.dx - prev.dx) * alpha,
        prev.dy + (current.dy - prev.dy) * alpha,
      );
    }

    return BodyPoseEstimate(
      leftShoulder: lerpOffset(leftShoulder, previous.leftShoulder),
      rightShoulder: lerpOffset(rightShoulder, previous.rightShoulder),
      leftHip: lerpOffset(leftHip, previous.leftHip),
      rightHip: lerpOffset(rightHip, previous.rightHip),
      nose: lerpOffset(nose, previous.nose),
      confidence: previous.confidence + (confidence - previous.confidence) * alpha,
    );
  }
}

/// Configuración paramétrica de la prueba de la prenda en pantalla.
class GarmentFittingConfig {
  /// Factor multiplicador por talla seleccionada (XS: 0.88, S: 0.94, M: 1.0, L: 1.08, XL: 1.16).
  final double sizeScaleMultiplier;

  /// Ajuste fino manual de escala por el usuario (-0.2 a +0.2).
  final double userScaleOffset;

  /// Ajuste vertical manual (para prendas que calzan más altas o bajas).
  final double userVerticalOffset;

  /// Si se dibuja el esqueleto de referencia anatómica para asistencia visual.
  final bool showLandmarkGuide;

  const GarmentFittingConfig({
    this.sizeScaleMultiplier = 1.0,
    this.userScaleOffset = 0.0,
    this.userVerticalOffset = 0.0,
    this.showLandmarkGuide = false,
  });

  double get totalScale => (sizeScaleMultiplier + userScaleOffset).clamp(0.6, 1.6);

  GarmentFittingConfig copyWith({
    double? sizeScaleMultiplier,
    double? userScaleOffset,
    double? userVerticalOffset,
    bool? showLandmarkGuide,
  }) {
    return GarmentFittingConfig(
      sizeScaleMultiplier: sizeScaleMultiplier ?? this.sizeScaleMultiplier,
      userScaleOffset: userScaleOffset ?? this.userScaleOffset,
      userVerticalOffset: userVerticalOffset ?? this.userVerticalOffset,
      showLandmarkGuide: showLandmarkGuide ?? this.showLandmarkGuide,
    );
  }

  /// Calcula el multiplicador de escala a partir de la descripción de la talla.
  static double scaleFromTalla(String descripcion) {
    final clean = descripcion.trim().toUpperCase();
    if (clean.contains('XS')) return 0.88;
    if (clean == 'S' || clean.startsWith('S ')) return 0.94;
    if (clean == 'M' || clean.startsWith('M ')) return 1.0;
    if (clean == 'L' || clean.startsWith('L ')) return 1.08;
    if (clean.contains('XL')) return 1.16;
    if (clean.contains('XXL')) return 1.24;
    return 1.0;
  }
}
