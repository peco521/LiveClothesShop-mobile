import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/catalogo.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/detalle_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu23_vestidor_virtual/models/vestidor_models.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu23_vestidor_virtual/widgets/clothing_overlay_painter.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu23_vestidor_virtual/screens/vestidor_screen.dart';

import 'catalogo_screen_test.dart';

ProductoDetalle _sampleProducto() {
  return const ProductoDetalle(
    idProd: 'P100',
    descripcion: 'Camisa Oxford Clásica',
    marca: 'Andes',
    categoria: 'Camisas',
    coleccion: 'Otoño 2026',
    promocion: null,
    variantes: [
      VarianteDetalle(
        id: 'VAR-1',
        sku: 'OXF-S-BLU',
        precio: 140.0,
        imagen: null,
        talla: TallaDetalle(id: 1, descripcion: 'S'),
        colores: [ColorDetalle(id: 1, descripcion: 'Azul', hex: '#0000FF')],
      ),
      VarianteDetalle(
        id: 'VAR-2',
        sku: 'OXF-M-WHT',
        precio: 150.0,
        imagen: null,
        talla: TallaDetalle(id: 2, descripcion: 'M'),
        colores: [ColorDetalle(id: 2, descripcion: 'Blanco', hex: '#FFFFFF')],
      ),
    ],
    disponibilidad: [
      DisponibilidadSucursal(
        nroSuc: 1,
        sucursal: 'Sucursal Central',
        ciudad: 'Cochabamba',
        idVariante: 'VAR-1',
        stock: 10,
        cantDisp: 8,
      ),
    ],
  );
}

void main() {
  group('CU23 Modelos y Geometría de Pose', () {
    test('BodyPoseEstimate calcula distancias, punto medio y rotación correctamente', () {
      const pose = BodyPoseEstimate(
        leftShoulder: Offset(100, 150),
        rightShoulder: Offset(200, 150),
        leftHip: Offset(110, 350),
        rightHip: Offset(190, 350),
        confidence: 0.95,
      );

      expect(pose.hasShoulders, isTrue);
      expect(pose.hasTorso, isTrue);

      final sMid = pose.shoulderMidpoint!;
      expect(sMid.dx, equals(150.0));
      expect(sMid.dy, equals(150.0));

      final hMid = pose.hipMidpoint!;
      expect(hMid.dx, equals(150.0));
      expect(hMid.dy, equals(350.0));

      expect(pose.shoulderWidth, closeTo(100.0, 0.01));
      expect(pose.torsoHeight, closeTo(200.0, 0.01));
      expect(pose.rotationAngle, closeTo(0.0, 0.01)); // Hombros horizontales
    });

    test('BodyPoseEstimate detecta inclinación de hombros (rotación de torso)', () {
      const poseInclinada = BodyPoseEstimate(
        leftShoulder: Offset(100, 100),
        rightShoulder: Offset(200, 200),
        confidence: 0.9,
      );

      expect(poseInclinada.rotationAngle, closeTo(math.pi / 4, 0.01)); // 45 grados
    });

    test('BodyPoseEstimate suavizado exponencial (EMA) filtra saltos bruscos', () {
      const pose1 = BodyPoseEstimate(
        leftShoulder: Offset(100, 100),
        rightShoulder: Offset(200, 100),
        confidence: 0.8,
      );
      const pose2 = BodyPoseEstimate(
        leftShoulder: Offset(120, 100),
        rightShoulder: Offset(220, 100),
        confidence: 0.9,
      );

      final smoothed = pose2.smoothWith(pose1, alpha: 0.5);
      expect(smoothed.leftShoulder!.dx, equals(110.0));
      expect(smoothed.rightShoulder!.dx, equals(210.0));
    });

    test('GarmentFittingConfig escala paramétrica según descripción de talla', () {
      expect(GarmentFittingConfig.scaleFromTalla('XS'), equals(0.88));
      expect(GarmentFittingConfig.scaleFromTalla('S'), equals(0.94));
      expect(GarmentFittingConfig.scaleFromTalla('M'), equals(1.0));
      expect(GarmentFittingConfig.scaleFromTalla('L'), equals(1.08));
      expect(GarmentFittingConfig.scaleFromTalla('XL'), equals(1.16));
    });
  });

  group('CU23 ClothingOverlayPainter', () {
    test('ClothingOverlayPainter no falla cuando no hay persona detectada', () {
      final painter = ClothingOverlayPainter(
        pose: null,
        cameraImageSize: const Size(720, 1280),
        isFrontCamera: true,
        garmentColor: Colors.blue,
        categoryName: 'Camisas',
        config: const GarmentFittingConfig(),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(360, 640)), returnsNormally);
    });

    test('ClothingOverlayPainter dibuja silueta proyectada con persona detectada', () {
      const pose = BodyPoseEstimate(
        leftShoulder: Offset(200, 300),
        rightShoulder: Offset(500, 300),
        leftHip: Offset(220, 700),
        rightHip: Offset(480, 700),
        confidence: 0.95,
      );

      final painter = ClothingOverlayPainter(
        pose: pose,
        cameraImageSize: const Size(720, 1280),
        isFrontCamera: false,
        garmentColor: const Color(0xFF2C3E50),
        categoryName: 'Camisas',
        config: const GarmentFittingConfig(showLandmarkGuide: true),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(360, 640)), returnsNormally);
    });
  });

  group('CU23 Integración con Detalle de Prenda y Vestidor', () {
    testWidgets('DetalleScreen incluye botón de acceso al vestidor virtual AR', (tester) async {
      final api = FakeCatalogoApi()..detalleObj = _sampleProducto();
      final session = SessionState(store: MemoryCredentialStore());
      await session.restore();

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/tienda/vestidor': (_) => const Scaffold(body: Text('Vista Vestidor AR Mock')),
          },
          home: ChangeNotifierProvider<SessionState>.value(
            value: session,
            child: DetalleScreen(idProd: 'P100', api: api),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final botonVestidor = find.text('Probar en vestidor virtual AR (CU23)');
      expect(botonVestidor, findsOneWidget);

      await tester.tap(botonVestidor);
      await tester.pumpAndSettle();

      expect(find.text('Vista Vestidor AR Mock'), findsOneWidget);
    });

    testWidgets('VestidorScreen muestra banner informativo de que probar no altera inventario', (tester) async {
      final session = SessionState(store: MemoryCredentialStore());
      await session.restore();

      final prod = _sampleProducto();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SessionState>.value(
            value: session,
            child: VestidorScreen(
              producto: prod,
              varianteInicial: prod.variantes.first,
            ),
          ),
        ),
      );

      await tester.pump();

      // Debe mostrar el banner transparente que aclara el alcance del vestidor
      expect(
        find.textContaining('La prueba no altera stock ni genera reservas'),
        findsOneWidget,
      );

      // Debe mostrar el botón de acción a CU11 (Reservas)
      expect(find.text('Reservar (CU11)'), findsOneWidget);

      // Debe mostrar el botón de acción a CU12 (Carrito)
      expect(find.textContaining('Al carrito (CU12)'), findsOneWidget);
    });
  });
}
