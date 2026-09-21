import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/garment_mesh.dart';
import '../services/garment_texture_service.dart';

/// Pinta la polera deformada con `Canvas.drawVertices` + `ImageShader` (CU16).
///
/// No se usa `drawImageRect`: la prenda se deforma vértice a vértice siguiendo
/// la pose, y los UV de la textura permanecen fijos.
class GarmentMeshPainter extends CustomPainter {
  GarmentMeshPainter({
    required this.malla,
    required this.textura,
    this.mostrarSombra = true,
  }) : super(repaint: malla);

  /// Malla actual. Es un `ValueListenable` (local, no un provider global), así
  /// que el repintado no reconstruye widgets ni publica estado por frame.
  final ValueListenable<GarmentMesh?> malla;

  final TexturaPrenda textura;

  /// Acabado sutil (sombra suave). Nunca se usa para tapar una malla mal hecha.
  final bool mostrarSombra;

  @override
  void paint(Canvas canvas, Size size) {
    final actual = malla.value;
    if (actual == null || !actual.esValida || !textura.esValida) return;
    if (actual.posiciones.length != actual.coordenadasTextura.length) return;

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      actual.posiciones,
      textureCoordinates: actual.coordenadasTextura,
      indices: actual.indices,
    );

    if (mostrarSombra) {
      canvas.save();
      canvas.translate(0, 5);
      canvas.drawVertices(
        vertices,
        BlendMode.srcOver,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    final shader = ui.ImageShader(
      textura.imagen,
      TileMode.clamp,
      TileMode.clamp,
      textura.matrizUv,
      filterQuality: FilterQuality.medium,
    );
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      Paint()
        ..shader = shader
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant GarmentMeshPainter anterior) =>
      anterior.textura.url != textura.url ||
      anterior.mostrarSombra != mostrarSombra ||
      !identical(anterior.malla, malla);
}
