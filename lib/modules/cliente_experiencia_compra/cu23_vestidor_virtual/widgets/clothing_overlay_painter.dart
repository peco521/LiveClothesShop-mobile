import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/vestidor_models.dart';

/// Painter que proyecta y adapta la prenda sobre el cuerpo de la persona
/// utilizando los landmarks anatómicos calculados en tiempo real.
class ClothingOverlayPainter extends CustomPainter {
  final BodyPoseEstimate? pose;
  final Size cameraImageSize;
  final bool isFrontCamera;
  final Color garmentColor;
  final String categoryName;
  final GarmentFittingConfig config;
  final ui.Image? textureImage;

  ClothingOverlayPainter({
    required this.pose,
    required this.cameraImageSize,
    required this.isFrontCamera,
    required this.garmentColor,
    required this.categoryName,
    required this.config,
    this.textureImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null || !pose!.hasShoulders || cameraImageSize.width == 0 || cameraImageSize.height == 0) {
      return;
    }

    // Calcular escala de transformación de imagen de cámara a tamaño de pantalla (BoxFit.cover)
    final double scaleX = size.width / cameraImageSize.width;
    final double scaleY = size.height / cameraImageSize.height;
    final double scale = math.max(scaleX, scaleY);

    final double offsetX = (size.width - cameraImageSize.width * scale) / 2.0;
    final double offsetY = (size.height - cameraImageSize.height * scale) / 2.0;

    Offset transformPoint(Offset point) {
      double px = point.dx * scale + offsetX;
      final double py = point.dy * scale + offsetY;
      if (isFrontCamera) {
        // En cámara frontal (efecto espejo), invertimos el eje horizontal
        px = size.width - px;
      }
      return Offset(px, py);
    }

    final pLeftShoulder = transformPoint(isFrontCamera ? pose!.rightShoulder! : pose!.leftShoulder!);
    final pRightShoulder = transformPoint(isFrontCamera ? pose!.leftShoulder! : pose!.rightShoulder!);

    final pLeftHip = pose!.leftHip != null
        ? transformPoint(isFrontCamera ? pose!.rightHip! : pose!.leftHip!)
        : Offset(pLeftShoulder.dx, pLeftShoulder.dy + 220);

    final pRightHip = pose!.rightHip != null
        ? transformPoint(isFrontCamera ? pose!.leftHip! : pose!.rightHip!)
        : Offset(pRightShoulder.dx, pRightShoulder.dy + 220);

    // Guía del esqueleto anatómico si está activada
    if (config.showLandmarkGuide) {
      _paintSkeletonGuide(canvas, pLeftShoulder, pRightShoulder, pLeftHip, pRightHip);
    }

    // Calcular métricas del torso para el anclaje de la prenda
    final sMid = Offset(
      (pLeftShoulder.dx + pRightShoulder.dx) / 2.0,
      (pLeftShoulder.dy + pRightShoulder.dy) / 2.0 + config.userVerticalOffset,
    );

    final hMid = Offset(
      (pLeftHip.dx + pRightHip.dx) / 2.0,
      (pLeftHip.dy + pRightHip.dy) / 2.0 + config.userVerticalOffset,
    );

    final dx = pRightShoulder.dx - pLeftShoulder.dx;
    final dy = pRightShoulder.dy - pLeftShoulder.dy;
    final shoulderDist = math.sqrt(dx * dx + dy * dy);
    final angle = math.atan2(dy, dx);

    final torsoDist = math.sqrt(
      math.pow(hMid.dx - sMid.dx, 2) + math.pow(hMid.dy - sMid.dy, 2),
    );

    // Factor de escala aplicado por talla y ajuste manual
    final fitScale = config.totalScale;
    final garmentWidth = shoulderDist * 1.55 * fitScale;
    final garmentHeight = math.max(torsoDist * 1.45, shoulderDist * 1.6) * fitScale;

    // Renderizar la prenda ajustada con transformación afín
    canvas.save();
    canvas.translate(sMid.dx, sMid.dy);
    canvas.rotate(angle);

    if (textureImage != null) {
      _paintGarmentTexture(canvas, garmentWidth, garmentHeight);
    } else {
      _paintGarmentSilhouette(canvas, garmentWidth, garmentHeight);
    }

    canvas.restore();
  }

  /// Dibuja la silueta vectorial paramétrica adaptada al torso
  void _paintGarmentSilhouette(Canvas canvas, double width, double height) {
    final isDress = categoryName.toLowerCase().contains('vestid');
    final isShirt = categoryName.toLowerCase().contains('camis') || categoryName.toLowerCase().contains('chaquet');

    final double effectiveHeight = isDress ? height * 1.6 : height;
    final halfW = width / 2.0;

    final path = Path();
    // Cuello
    path.moveTo(-halfW * 0.25, 0);
    path.quadraticBezierTo(0, height * 0.12, halfW * 0.25, 0);

    // Hombro derecho y manga derecha
    path.lineTo(halfW * 0.85, height * 0.04);
    path.lineTo(halfW * 1.15, height * 0.28); // Extremo manga
    path.lineTo(halfW * 0.85, height * 0.38); // Axila derecha

    // Costado derecho del torso
    if (isDress) {
      path.quadraticBezierTo(halfW * 0.65, height * 0.6, halfW * 1.05, effectiveHeight);
    } else {
      path.lineTo(halfW * 0.68, effectiveHeight);
    }

    // Dobladillo inferior
    path.quadraticBezierTo(0, effectiveHeight + height * 0.06, -halfW * (isDress ? 1.05 : 0.68), effectiveHeight);

    // Costado izquierdo del torso
    if (isDress) {
      path.quadraticBezierTo(-halfW * 0.65, height * 0.6, -halfW * 0.85, height * 0.38);
    } else {
      path.lineTo(-halfW * 0.85, height * 0.38); // Axila izquierda
    }

    // Manga izquierda y hombro izquierdo
    path.lineTo(-halfW * 1.15, height * 0.28);
    path.lineTo(-halfW * 0.85, height * 0.04);
    path.close();

    // Relleno con degradado suave y color de variante
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        garmentColor.withValues(alpha: 0.92),
        garmentColor.withValues(alpha: 0.82),
        garmentColor.withValues(alpha: 0.88),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(-halfW * 1.2, 0, width * 1.2, effectiveHeight))
      ..style = PaintingStyle.fill;

    // Sombra de drapeado para realismo
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    // Borde de costura
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);

    // Detalles: cuello y botones si es camisa
    if (isShirt) {
      final buttonLine = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(const Offset(0, 15), Offset(0, effectiveHeight - 10), buttonLine);

      // Botones
      final buttonPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
      for (double y = height * 0.2; y < effectiveHeight - 20; y += 45) {
        canvas.drawCircle(Offset(0, y), 3.5, buttonPaint);
      }
    }
  }

  /// Proyecta la textura real de la prenda escalada sobre el torso
  void _paintGarmentTexture(Canvas canvas, double width, double height) {
    if (textureImage == null) return;

    final src = Rect.fromLTWH(0, 0, textureImage!.width.toDouble(), textureImage!.height.toDouble());
    final dst = Rect.fromLTWH(-width / 2.0, -height * 0.1, width, height * 1.2);

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = garmentColor.withValues(alpha: 0.9);

    canvas.drawImageRect(textureImage!, src, dst, paint);
  }

  /// Dibuja los landmarks de referencia anatómica
  void _paintSkeletonGuide(
    Canvas canvas,
    Offset ls,
    Offset rs,
    Offset lh,
    Offset rh,
  ) {
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    // Línea entre hombros
    canvas.drawLine(ls, rs, linePaint);
    // Torso (hombros a caderas)
    canvas.drawLine(ls, lh, linePaint);
    canvas.drawLine(rs, rh, linePaint);
    canvas.drawLine(lh, rh, linePaint);

    // Nodos en articulaciones
    canvas.drawCircle(ls, 6.0, jointPaint);
    canvas.drawCircle(rs, 6.0, jointPaint);
    canvas.drawCircle(lh, 6.0, jointPaint);
    canvas.drawCircle(rh, 6.0, jointPaint);
  }

  @override
  bool shouldRepaint(covariant ClothingOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.garmentColor != garmentColor ||
        oldDelegate.config != config ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
