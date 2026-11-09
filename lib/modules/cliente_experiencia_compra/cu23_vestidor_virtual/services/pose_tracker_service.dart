import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/vestidor_models.dart';

/// Servicio responsable de procesar frames de la cámara y calcular la estimación
/// de puntos anatómicos para anclar prendas sobre el cuerpo del cliente.
class PoseTrackerService {
  final PoseDetector _detector;
  bool _isProcessing = false;
  BodyPoseEstimate? _lastEstimate;

  PoseTrackerService({PoseDetector? detector})
      : _detector = detector ??
            PoseDetector(
              options: PoseDetectorOptions(
                model: PoseDetectionModel.base,
                mode: PoseDetectionMode.stream,
              ),
            );

  BodyPoseEstimate? get lastEstimate => _lastEstimate;

  /// Procesa un frame de la cámara y retorna la estimación anatómica si detecta una persona.
  /// Evita encolamiento de frames si el detector está ocupado.
  Future<BodyPoseEstimate?> processFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) return null;

      final poses = await _detector.processImage(inputImage);
      if (poses.isEmpty) {
        _lastEstimate = null;
        return null;
      }

      final pose = poses.first;
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
      final nose = pose.landmarks[PoseLandmarkType.nose];

      if (leftShoulder == null || rightShoulder == null) {
        _lastEstimate = null;
        return null;
      }

      final rawEstimate = BodyPoseEstimate(
        leftShoulder: Offset(leftShoulder.x, leftShoulder.y),
        rightShoulder: Offset(rightShoulder.x, rightShoulder.y),
        leftHip: leftHip != null ? Offset(leftHip.x, leftHip.y) : null,
        rightHip: rightHip != null ? Offset(rightHip.x, rightHip.y) : null,
        nose: nose != null ? Offset(nose.x, nose.y) : null,
        confidence: (leftShoulder.likelihood + rightShoulder.likelihood) / 2.0,
      );

      // Aplica suavizado exponencial para eliminar vibraciones de tracking
      _lastEstimate = rawEstimate.smoothWith(_lastEstimate, alpha: 0.65);
      return _lastEstimate;
    } catch (e) {
      debugPrint('Error en PoseTrackerService.processFrame: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Construye un [InputImage] a partir del frame nativo de CameraX / Camera2.
  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isAndroid) {
      var rotationCompensation = _orientations[sensorOrientation];
      if (camera.lensDirection == CameraLensDirection.front) {
        // Compensación de cámara frontal
        rotationCompensation = (sensorOrientation + 0) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation ?? 0);
    } else if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    rotation ??= InputImageRotation.rotation0deg;

    // Obtener formato de imagen
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Concatenar planos en búfer contiguo para ML Kit
    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// Libera los recursos del motor de pose en GPU/NPU.
  Future<void> dispose() async {
    _isProcessing = false;
    _lastEstimate = null;
    await _detector.close();
  }

  static const Map<int, int> _orientations = {
    0: 0,
    90: 90,
    180: 180,
    270: 270,
  };
}
