import 'dart:ui';

import '../models/garment_mesh.dart';
import '../models/garment_vertex.dart';
import '../models/pose_frame.dart';
import '../utils/landmark_helpers.dart';
import '../utils/pose_coordinates.dart';

/// Construye la malla deformable de la polera a partir de la pose (CU16).
///
/// No hay rectángulo rígido: cada fila del torso se calcula con el eje real del
/// cuerpo (hombros → caderas) y con el ancho correspondiente, así que la polera
/// sigue la inclinación de los hombros, el ancho del pecho/cintura y las mangas
/// apuntan hacia los codos.
class GarmentMeshService {
  const GarmentMeshService({
    this.factorManga = factorMangaPorDefecto,
    this.anchoManga = anchoMangaPorDefecto,
    this.alturaCuello = alturaCuelloPorDefecto,
    this.alturaBorde = alturaBordePorDefecto,
    this.escalaHombros = escalaHombrosPorDefecto,
    this.escalaPecho = escalaPechoPorDefecto,
    this.escalaBorde = escalaBordePorDefecto,
  });

  /// Punto de la manga entre hombro y codo (rango pedido: 0.45 - 0.60).
  static const double factorMangaPorDefecto = 0.52;

  /// Ancho de la manga como fracción de la longitud hombro→codo.
  static const double anchoMangaPorDefecto = 0.42;

  /// Cuánto sube el cuello por encima de la línea de hombros.
  static const double alturaCuelloPorDefecto = 0.14;

  /// Cuánto baja el ruedo por debajo de la línea de cadera.
  static const double alturaBordePorDefecto = 0.14;

  /// Holguras de la prenda sobre el cuerpo (una polera no va pegada).
  static const double escalaHombrosPorDefecto = 1.02;
  static const double escalaPechoPorDefecto = 1.06;
  static const double escalaBordePorDefecto = 1.14;

  final double factorManga;
  final double anchoManga;
  final double alturaCuello;
  final double alturaBorde;
  final double escalaHombros;
  final double escalaPecho;
  final double escalaBorde;

  /// Cuello derivado: ML Kit no entrega cuello, se calcula como el punto medio
  /// de los hombros.
  Offset? nudoCuello(PoseFrame pose) => pose.centroCuello;

  /// Centro de la manga: `lerp(hombro, codo, factorManga)`.
  Offset? puntoManga(
    PoseFrame pose, {
    required bool izquierda,
    double? factor,
  }) {
    final hombro = izquierda ? pose.hombroIzquierdo : pose.hombroDerecho;
    final codo = izquierda ? pose.codoIzquierdo : pose.codoDerecho;
    if (hombro == null || codo == null) return null;
    return interpolar(hombro.punto, codo.punto, factor ?? factorManga);
  }

  /// Malla en coordenadas de CANVAS: convierte la pose de la cámara con
  /// [coordenadas] (rotación, recorte `cover` y espejo de cámara frontal).
  GarmentMesh? construir({
    required PoseFrame pose,
    required PoseCoordinates coordenadas,
  }) {
    if (!coordenadas.utilizable) return null;
    return construirEnLienzo(pose: _aLienzo(pose, coordenadas));
  }

  /// Malla a partir de una pose YA expresada en coordenadas del Canvas.
  ///
  /// Devuelve `null` cuando el torso no es visible: nunca se dibuja una polera
  /// deformada sobre una pose incompleta.
  GarmentMesh? construirEnLienzo({required PoseFrame pose}) {
    if (!pose.torsoVisible) return null;

    final hombroIzq = pose.hombroIzquierdo!.punto;
    final hombroDer = pose.hombroDerecho!.punto;
    final caderaIzq = pose.caderaIzquierda!.punto;
    final caderaDer = pose.caderaDerecha!.punto;

    final centroCuello = pose.centroCuello!;
    final centroCadera = pose.centroCadera!;

    // Eje vertical del torso (puede estar inclinado: no se asume vertical).
    final haciaAbajo =
        direccionUnitaria(centroCuello, centroCadera) ?? const Offset(0, 1);
    // Eje lateral: del hombro derecho al izquierdo, así "izquierda" de la malla
    // coincide con la izquierda de la persona que se ve en el preview.
    final haciaIzquierda =
        direccionUnitaria(hombroDer, hombroIzq) ?? const Offset(-1, 0);

    final anchoHombros = distancia(hombroIzq, hombroDer) ?? 0;
    final anchoCaderas = distancia(caderaIzq, caderaDer) ?? anchoHombros;
    final largoTorso = distancia(centroCuello, centroCadera) ?? 0;
    if (anchoHombros <= 0 || largoTorso <= 0) return null;

    // Pecho y cintura se derivan interpolando hombros → caderas.
    final filaCuello = _Fila(
      centro: avanzar(centroCuello, haciaAbajo, -largoTorso * alturaCuello),
      semiancho: anchoHombros * 0.22,
    );
    final filaHombros = _Fila(
      centro: centroCuello,
      semiancho: anchoHombros / 2 * escalaHombros,
    );
    final filaPecho = _Fila(
      centro: interpolarPunto(centroCuello, centroCadera, 0.45),
      semiancho:
          _semianchoInterpolado(anchoHombros, anchoCaderas, 0.45) * escalaPecho,
    );
    final filaCintura = _Fila(
      centro: interpolarPunto(centroCuello, centroCadera, 0.75),
      semiancho: _semianchoInterpolado(anchoHombros, anchoCaderas, 0.75),
    );
    final filaBorde = _Fila(
      centro: interpolarPunto(centroCuello, centroCadera, 1 + alturaBorde),
      semiancho: anchoCaderas / 2 * escalaBorde,
    );

    final mangaIzq = _manga(
      hombro: hombroIzq,
      codo: pose.codoIzquierdo?.punto,
      haciaIzquierda: haciaIzquierda,
      haciaAbajo: haciaAbajo,
      signo: 1,
      anchoHombros: anchoHombros,
    );
    final mangaDer = _manga(
      hombro: hombroDer,
      codo: pose.codoDerecho?.punto,
      haciaIzquierda: haciaIzquierda,
      haciaAbajo: haciaAbajo,
      signo: -1,
      anchoHombros: anchoHombros,
    );

    final uvs = GarmentMesh.uvPorDefecto;
    final vertices = <GarmentVertex>[
      _vertice(filaCuello, haciaIzquierda, 1, uvs[GarmentMesh.cuelloIzq]),
      _vertice(filaCuello, haciaIzquierda, -1, uvs[GarmentMesh.cuelloDer]),
      _vertice(filaHombros, haciaIzquierda, 1, uvs[GarmentMesh.hombroIzq]),
      _vertice(filaHombros, haciaIzquierda, -1, uvs[GarmentMesh.hombroDer]),
      GarmentVertex(
        posicion: mangaIzq.exterior,
        uv: uvs[GarmentMesh.mangaExteriorIzq],
      ),
      GarmentVertex(
        posicion: mangaIzq.puntaExterior,
        uv: uvs[GarmentMesh.puntaExteriorIzq],
      ),
      GarmentVertex(
        posicion: mangaIzq.puntaInterior,
        uv: uvs[GarmentMesh.puntaInteriorIzq],
      ),
      GarmentVertex(
        posicion: mangaDer.exterior,
        uv: uvs[GarmentMesh.mangaExteriorDer],
      ),
      GarmentVertex(
        posicion: mangaDer.puntaExterior,
        uv: uvs[GarmentMesh.puntaExteriorDer],
      ),
      GarmentVertex(
        posicion: mangaDer.puntaInterior,
        uv: uvs[GarmentMesh.puntaInteriorDer],
      ),
      _vertice(filaPecho, haciaIzquierda, 1, uvs[GarmentMesh.pechoIzq]),
      _vertice(filaPecho, haciaIzquierda, -1, uvs[GarmentMesh.pechoDer]),
      _vertice(filaCintura, haciaIzquierda, 1, uvs[GarmentMesh.cinturaIzq]),
      _vertice(filaCintura, haciaIzquierda, -1, uvs[GarmentMesh.cinturaDer]),
      _vertice(filaBorde, haciaIzquierda, 1, uvs[GarmentMesh.bordeIzq]),
      _vertice(filaBorde, haciaIzquierda, -1, uvs[GarmentMesh.bordeDer]),
    ];

    final malla = GarmentMesh(vertices: vertices);
    return malla.esValida ? malla : null;
  }

  double _semianchoInterpolado(
    double anchoHombros,
    double anchoCaderas,
    double t,
  ) => interpolarPunto(
    Offset(anchoHombros / 2, 0),
    Offset(anchoCaderas / 2, 0),
    t,
  ).dx;

  GarmentVertex _vertice(
    _Fila fila,
    Offset haciaIzquierda,
    int lado,
    Offset uv,
  ) => GarmentVertex(
    posicion: Offset(
      fila.centro.dx + haciaIzquierda.dx * fila.semiancho * lado,
      fila.centro.dy + haciaIzquierda.dy * fila.semiancho * lado,
    ),
    uv: uv,
  );

  _Manga _manga({
    required Offset hombro,
    required Offset? codo,
    required Offset haciaIzquierda,
    required Offset haciaAbajo,
    required int signo,
    required double anchoHombros,
  }) {
    // Sin codo confiable se estima el brazo cayendo junto al torso: la manga
    // queda razonable en vez de desaparecer.
    final direccion =
        direccionUnitaria(hombro, codo) ??
        _normalizar(
          Offset(
            haciaIzquierda.dx * signo * 0.45 + haciaAbajo.dx,
            haciaIzquierda.dy * signo * 0.45 + haciaAbajo.dy,
          ),
        );
    final largo = distancia(hombro, codo) ?? anchoHombros * 0.62;
    final normal = _normalHacia(direccion, haciaIzquierda, signo);
    final medio = avanzar(hombro, direccion, largo * factorManga);
    final mitad = largo * anchoManga / 2;
    return _Manga(
      exterior: avanzar(
        avanzar(hombro, direccion, largo * factorManga * 0.55),
        normal,
        mitad * 1.05,
      ),
      puntaExterior: avanzar(medio, normal, mitad),
      puntaInterior: avanzar(medio, normal, -mitad),
    );
  }

  Offset _normalizar(Offset vector) {
    final largo = vector.distance;
    if (largo < 0.0001) return const Offset(0, 1);
    return vector / largo;
  }

  /// Perpendicular a [direccion] orientada hacia afuera del torso.
  Offset _normalHacia(Offset direccion, Offset haciaIzquierda, int signo) {
    final normal = perpendicularUnitaria(direccion);
    final haciaFuera =
        normal.dx * haciaIzquierda.dx + normal.dy * haciaIzquierda.dy;
    return haciaFuera * signo >= 0 ? normal : -normal;
  }

  PoseFrame _aLienzo(PoseFrame pose, PoseCoordinates coordenadas) {
    PoseLandmark? convierte(PoseLandmark? punto) {
      if (punto == null) return null;
      final lienzo = coordenadas.aLienzo(punto.punto);
      return PoseLandmark(
        x: lienzo.dx,
        y: lienzo.dy,
        probabilidad: punto.probabilidad,
      );
    }

    return PoseFrame(
      hombroIzquierdo: convierte(pose.hombroIzquierdo),
      hombroDerecho: convierte(pose.hombroDerecho),
      codoIzquierdo: convierte(pose.codoIzquierdo),
      codoDerecho: convierte(pose.codoDerecho),
      caderaIzquierda: convierte(pose.caderaIzquierda),
      caderaDerecha: convierte(pose.caderaDerecha),
      munecaIzquierda: convierte(pose.munecaIzquierda),
      munecaDerecha: convierte(pose.munecaDerecha),
    );
  }
}

/// Fila del torso: centro y semiancho.
class _Fila {
  const _Fila({required this.centro, required this.semiancho});

  final Offset centro;
  final double semiancho;
}

/// Los tres puntos de una manga.
class _Manga {
  const _Manga({
    required this.exterior,
    required this.puntaExterior,
    required this.puntaInterior,
  });

  final Offset exterior;
  final Offset puntaExterior;
  final Offset puntaInterior;
}
