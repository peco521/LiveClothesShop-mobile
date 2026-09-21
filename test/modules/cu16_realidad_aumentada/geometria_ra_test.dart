import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/models/garment_mesh.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/models/pose_frame.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/services/garment_mesh_service.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/services/garment_texture_service.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/services/pose_smoother.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/utils/pose_coordinates.dart';

/// Punto de pose para las pruebas (confianza alta por defecto).
PoseLandmark punto(double x, double y, [double probabilidad = 0.9]) =>
    PoseLandmark(x: x, y: y, probabilidad: probabilidad);

/// Persona de frente: hombros a 300 y caderas a 500 de alto.
PoseFrame poseDeFrente({
  Offset hombroIzq = const Offset(200, 300),
  Offset hombroDer = const Offset(400, 300),
  Offset caderaIzq = const Offset(220, 500),
  Offset caderaDer = const Offset(380, 500),
  Offset codoIzq = const Offset(120, 430),
  Offset codoDer = const Offset(480, 430),
  double confianza = 0.9,
}) => PoseFrame(
  hombroIzquierdo: punto(hombroIzq.dx, hombroIzq.dy, confianza),
  hombroDerecho: punto(hombroDer.dx, hombroDer.dy, confianza),
  caderaIzquierda: punto(caderaIzq.dx, caderaIzq.dy, confianza),
  caderaDerecha: punto(caderaDer.dx, caderaDer.dy, confianza),
  codoIzquierdo: punto(codoIzq.dx, codoIzq.dy, confianza),
  codoDerecho: punto(codoDer.dx, codoDer.dy, confianza),
);

void main() {
  const servicio = GarmentMeshService();

  group('CU16 geometría', () {
    test('1. el cuello derivado es el punto medio de los hombros', () {
      final pose = poseDeFrente();
      expect(pose.centroCuello, const Offset(300, 300));
      expect(servicio.nudoCuello(pose), const Offset(300, 300));
      expect(pose.centroCadera, const Offset(300, 500));
      // Pecho y cintura se interpolan entre cuello y cadera.
      expect(pose.centroPecho, const Offset(300, 390));
      expect(pose.centroCintura, const Offset(300, 444));
    });

    test('2. la manga se calcula entre hombro y codo (nunca en la muñeca)', () {
      final pose = poseDeFrente();
      final manga = servicio.puntoManga(pose, izquierda: true);
      expect(manga, isNotNull);
      expect(servicio.factorManga, inInclusiveRange(0.45, 0.60));
      final hombro = pose.hombroIzquierdo!.punto;
      final codo = pose.codoIzquierdo!.punto;
      // Está sobre el segmento hombro→codo y a la distancia pedida.
      expect(
        (manga! - hombro).distance + (manga - codo).distance,
        closeTo((hombro - codo).distance, 0.001),
      );
      expect(
        (manga - hombro).distance,
        closeTo((hombro - codo).distance * servicio.factorManga, 0.001),
      );
    });

    test(
      '3. la imagen de cámara se convierte al preview con recorte cover',
      () {
        final coords = PoseCoordinates(
          tamanoFrame: const Size(720, 1280),
          tamanoLienzo: const Size(360, 640),
          espejo: false,
        );
        expect(coords.escala, closeTo(0.5, 0.0001));
        expect(coords.aLienzo(Offset.zero), Offset.zero);
        expect(coords.aLienzo(const Offset(720, 1280)), const Offset(360, 640));

        // Lienzo más chato que el frame: el recorte es vertical (cover).
        final recortado = PoseCoordinates(
          tamanoFrame: const Size(720, 1280),
          tamanoLienzo: const Size(720, 800),
          espejo: false,
        );
        expect(recortado.escala, closeTo(1, 0.0001));
        expect(recortado.aLienzo(const Offset(0, 0)).dy, closeTo(-240, 0.0001));
        expect(
          recortado.aLienzo(const Offset(0, 640)).dy,
          closeTo(400, 0.0001),
        );
      },
    );

    test('4. el espejo frontal se aplica una sola vez', () {
      final coords = PoseCoordinates(
        tamanoFrame: const Size(720, 1280),
        tamanoLienzo: const Size(720, 1280),
        espejo: true,
      );
      expect(coords.aLienzo(const Offset(100, 50)), const Offset(620, 50));
      expect(
        coords.aLienzoSinEspejo(const Offset(100, 50)),
        const Offset(100, 50),
      );
      expect(
        PoseCoordinates.espejoX(const Offset(100, 50), 720),
        const Offset(620, 50),
      );
      // Sin cámara frontal no se espeja nada.
      final trasera = PoseCoordinates(
        tamanoFrame: const Size(720, 1280),
        tamanoLienzo: const Size(720, 1280),
        espejo: false,
      );
      expect(trasera.aLienzo(const Offset(100, 50)), const Offset(100, 50));
    });

    test('5. el suavizado EMA mezcla el frame nuevo con el anterior', () {
      final suavizador = PoseSmoother(alpha: 0.5);
      final primera = poseDeFrente();
      expect(suavizador.suavizar(primera), primera);

      final segunda = poseDeFrente(hombroIzq: const Offset(300, 300));
      final suave = suavizador.suavizar(segunda);
      expect(suave, isNotNull);
      expect(suave!.hombroIzquierdo!.x, closeTo(250, 0.001));
      // La confianza mostrada es la del frame nuevo (no se oculta un punto malo).
      expect(
        suave.hombroIzquierdo!.probabilidad,
        segunda.hombroIzquierdo!.probabilidad,
      );
    });

    test('6-8. la malla es válida, con UV fijos e índices en rango', () {
      final malla = servicio.construirEnLienzo(pose: poseDeFrente());
      expect(malla, isNotNull);
      expect(malla!.vertices.length, GarmentMesh.totalVertices);
      expect(malla.posiciones.length, malla.coordenadasTextura.length);
      expect(malla.indices.length, GarmentMesh.triangulos.length);
      expect(malla.indices.length % 3, 0);
      for (final indice in malla.indices) {
        expect(indice, inInclusiveRange(0, GarmentMesh.totalVertices - 1));
      }
      expect(malla.esValida, isTrue);
      expect(malla.coordenadasTextura, GarmentMesh.uvPorDefecto);

      // Los UV son fijos; las posiciones cambian con la pose.
      final otra = servicio.construirEnLienzo(
        pose: poseDeFrente(hombroDer: const Offset(500, 300)),
      )!;
      expect(otra.coordenadasTextura, malla.coordenadasTextura);
      expect(
        otra.posiciones[GarmentMesh.hombroDer],
        isNot(malla.posiciones[GarmentMesh.hombroDer]),
      );
      expect(
        otra.posiciones[GarmentMesh.hombroDer].dx,
        greaterThan(malla.posiciones[GarmentMesh.hombroDer].dx),
      );
    });

    test('6b. la malla acompaña la inclinación de los hombros', () {
      final inclinada = servicio.construirEnLienzo(
        pose: poseDeFrente(
          hombroIzq: const Offset(200, 340),
          hombroDer: const Offset(400, 300),
        ),
      )!;
      final cuelloIzq = inclinada.posiciones[GarmentMesh.cuelloIzq];
      final cuelloDer = inclinada.posiciones[GarmentMesh.cuelloDer];
      // No es un rectángulo horizontal: la fila del cuello queda inclinada.
      expect(cuelloIzq.dy, isNot(closeTo(cuelloDer.dy, 0.01)));
      expect(cuelloIzq.dx, lessThan(cuelloDer.dx));
    });

    test('9. una pose incompleta no genera malla', () {
      expect(servicio.construirEnLienzo(pose: const PoseFrame()), isNull);

      final sinCaderas = PoseFrame(
        hombroIzquierdo: punto(200, 300),
        hombroDerecho: punto(400, 300),
      );
      expect(sinCaderas.torsoVisible, isFalse);
      expect(servicio.construirEnLienzo(pose: sinCaderas), isNull);

      // Confianza insuficiente: no se deforma la prenda a partir de ruido.
      final dudosa = poseDeFrente(confianza: 0.3);
      expect(dudosa.torsoVisible, isFalse);
      expect(servicio.construirEnLienzo(pose: dudosa), isNull);
    });

    test('10. el suavizado se reinicia sin arrastrar coordenadas viejas', () {
      final suavizador = PoseSmoother(
        alpha: 0.5,
        framesInvalidosParaReiniciar: 3,
      );
      suavizador.suavizar(poseDeFrente());
      expect(suavizador.actual, isNotNull);

      for (var i = 0; i < 3; i++) {
        expect(suavizador.suavizar(const PoseFrame()), isNull);
      }
      expect(suavizador.actual, isNull);

      // Con el historial limpio, la pose nueva entra tal cual.
      final nueva = poseDeFrente(hombroIzq: const Offset(600, 300));
      expect(suavizador.suavizar(nueva), nueva);

      suavizador.reset();
      expect(suavizador.actual, isNull);
      expect(suavizador.framesInvalidos, 0);
    });

    test('11. el bounding box alfa mide la zona real de la prenda', () {
      const ancho = 10;
      const alto = 10;
      final bytes = Uint8List(ancho * alto * 4);
      for (var y = 3; y <= 8; y++) {
        for (var x = 2; x <= 7; x++) {
          bytes[(y * ancho + x) * 4 + 3] = 255;
        }
      }
      final rect = GarmentTextureService.boundingBoxAlfa(
        ByteData.sublistView(bytes),
        ancho,
        alto,
        paso: 1,
      )!;
      expect(rect.left, closeTo(0.2, 0.0001));
      expect(rect.top, closeTo(0.3, 0.0001));
      expect(rect.right, closeTo(0.8, 0.0001));
      expect(rect.bottom, closeTo(0.9, 0.0001));

      // Imagen totalmente transparente: no hay prenda que medir.
      expect(
        GarmentTextureService.boundingBoxAlfa(
          ByteData.sublistView(Uint8List(ancho * alto * 4)),
          ancho,
          alto,
        ),
        isNull,
      );

      // Imagen opaca (por ejemplo un JPG con fondo): se usa completa.
      final opaca = Uint8List(ancho * alto * 4);
      opaca.fillRange(0, opaca.length, 255);
      final completa = GarmentTextureService.boundingBoxAlfa(
        ByteData.sublistView(opaca),
        ancho,
        alto,
        paso: 1,
      )!;
      expect(completa.left, closeTo(0, 0.0001));
      expect(completa.top, closeTo(0, 0.0001));
      expect(completa.right, closeTo(1, 0.0001));
      expect(completa.bottom, closeTo(1, 0.0001));
    });
  });
}
