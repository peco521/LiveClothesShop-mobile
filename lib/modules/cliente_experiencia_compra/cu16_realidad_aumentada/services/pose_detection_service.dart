import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    hide PoseLandmark;

import '../models/pose_frame.dart';

/// Detección de pose en tiempo real con ML Kit (una persona, modo stream).
///
/// Es el ÚNICO lugar del proyecto que conoce ML Kit: el resto de CU16 trabaja
/// con `PoseFrame`, lo que permite probar la geometría sin dispositivo.
class PoseDetectionService {
  PoseDetectionService()
    : _detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );

  final PoseDetector _detector;
  bool _cerrado = false;

  /// Procesa un frame de la cámara (NV21, un solo plano) y devuelve la pose.
  ///
  /// [gradosRotacion] viene de `PoseCoordinates.gradosParaInputImage` (sensor +
  /// orientación del dispositivo): nunca se asume un valor fijo.
  Future<PoseFrame?> detectar({
    required CameraImage imagen,
    required int gradosRotacion,
  }) async {
    if (_cerrado || imagen.planes.isEmpty) return null;
    final rotacion = rotacionDesdeGrados(gradosRotacion);
    if (rotacion == null) return null;
    final plano = imagen.planes.first;
    final input = InputImage.fromBytes(
      bytes: plano.bytes,
      metadata: InputImageMetadata(
        size: Size(imagen.width.toDouble(), imagen.height.toDouble()),
        rotation: rotacion,
        format: InputImageFormat.nv21,
        bytesPerRow: plano.bytesPerRow,
      ),
    );
    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return null;
    return aPoseFrame(poses.first);
  }

  /// Traduce los 33 landmarks de ML Kit a los que CU16 usa.
  static PoseFrame aPoseFrame(Pose pose) {
    PoseLandmark? punto(PoseLandmarkType tipo) {
      final landmark = pose.landmarks[tipo];
      if (landmark == null) return null;
      return PoseLandmark(
        x: landmark.x,
        y: landmark.y,
        probabilidad: landmark.likelihood,
      );
    }

    return PoseFrame(
      hombroIzquierdo: punto(PoseLandmarkType.leftShoulder),
      hombroDerecho: punto(PoseLandmarkType.rightShoulder),
      codoIzquierdo: punto(PoseLandmarkType.leftElbow),
      codoDerecho: punto(PoseLandmarkType.rightElbow),
      caderaIzquierda: punto(PoseLandmarkType.leftHip),
      caderaDerecha: punto(PoseLandmarkType.rightHip),
      munecaIzquierda: punto(PoseLandmarkType.leftWrist),
      munecaDerecha: punto(PoseLandmarkType.rightWrist),
    );
  }

  static InputImageRotation? rotacionDesdeGrados(int grados) =>
      switch (((grados % 360) + 360) % 360) {
        0 => InputImageRotation.rotation0deg,
        90 => InputImageRotation.rotation90deg,
        180 => InputImageRotation.rotation180deg,
        270 => InputImageRotation.rotation270deg,
        _ => null,
      };

  /// Libera el detector nativo (se llama al salir de CU16).
  Future<void> cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    await _detector.close();
  }
}
