import '../models/pose_frame.dart';
import '../utils/landmark_helpers.dart';

/// Suavizado temporal de la pose con EMA (`Exponential Moving Average`).
///
/// `suave = alpha * nuevo + (1 - alpha) * anterior`
///
/// El filtro se reinicia cuando la pose se pierde varios frames o cuando un
/// punto "salta" demasiado (la persona se movió de golpe, entró/salió del
/// encuadre, cambió la cámara o la orientación): así nunca se arrastran
/// coordenadas viejas.
class PoseSmoother {
  PoseSmoother({
    this.alpha = alphaPorDefecto,
    this.framesInvalidosParaReiniciar = framesInvalidosPorDefecto,
    this.saltoMaximo = saltoMaximoPorDefecto,
  });

  /// Peso del frame nuevo (centralizado: rango recomendado 0.25 - 0.45).
  static const double alphaPorDefecto = 0.35;

  /// Frames seguidos sin torso válido antes de olvidar el historial.
  static const int framesInvalidosPorDefecto = 6;

  /// Salto (en píxeles de pantalla) que se considera "persona distinta".
  static const double saltoMaximoPorDefecto = 140;

  final double alpha;
  final int framesInvalidosParaReiniciar;
  final double saltoMaximo;

  PoseFrame? _anterior;
  int _framesInvalidos = 0;

  /// Última pose suavizada (o `null` si todavía no hay historial).
  PoseFrame? get actual => _anterior;

  /// Frames consecutivos sin torso válido.
  int get framesInvalidos => _framesInvalidos;

  /// Aplica el filtro. Devuelve `null` cuando la pose nueva no permite dibujar
  /// (torso incompleto): en ese caso CU16 no deforma la polera.
  PoseFrame? suavizar(PoseFrame nuevo) {
    if (!nuevo.torsoVisible) {
      _framesInvalidos++;
      if (_framesInvalidos >= framesInvalidosParaReiniciar) {
        reset(contarInvalidos: false);
      }
      return null;
    }
    final previo = _anterior;
    _framesInvalidos = 0;
    if (previo == null || _saltoGrande(previo, nuevo)) {
      _anterior = nuevo;
      return nuevo;
    }
    final suave = _mezclar(previo, nuevo);
    _anterior = suave;
    return suave;
  }

  /// Olvida el historial (fin de sesión, cambio de cámara u orientación).
  void reset({bool contarInvalidos = true}) {
    _anterior = null;
    if (contarInvalidos) _framesInvalidos = 0;
  }

  PoseFrame _mezclar(PoseFrame anterior, PoseFrame nuevo) => PoseFrame(
    hombroIzquierdo: _punto(anterior.hombroIzquierdo, nuevo.hombroIzquierdo),
    hombroDerecho: _punto(anterior.hombroDerecho, nuevo.hombroDerecho),
    codoIzquierdo: _punto(anterior.codoIzquierdo, nuevo.codoIzquierdo),
    codoDerecho: _punto(anterior.codoDerecho, nuevo.codoDerecho),
    caderaIzquierda: _punto(anterior.caderaIzquierda, nuevo.caderaIzquierda),
    caderaDerecha: _punto(anterior.caderaDerecha, nuevo.caderaDerecha),
    munecaIzquierda: _punto(anterior.munecaIzquierda, nuevo.munecaIzquierda),
    munecaDerecha: _punto(anterior.munecaDerecha, nuevo.munecaDerecha),
  );

  PoseLandmark? _punto(PoseLandmark? anterior, PoseLandmark? nuevo) {
    if (nuevo == null) return anterior;
    if (anterior == null) return nuevo;
    final mezcla = interpolarPunto(anterior.punto, nuevo.punto, alpha);
    return PoseLandmark(
      x: mezcla.dx,
      y: mezcla.dy,
      probabilidad: nuevo.probabilidad,
    );
  }

  /// ¿Algún punto compartido se movió más de [saltoMaximo]?
  bool _saltoGrande(PoseFrame anterior, PoseFrame nuevo) {
    final pares = <List<PoseLandmark?>>[
      [anterior.hombroIzquierdo, nuevo.hombroIzquierdo],
      [anterior.hombroDerecho, nuevo.hombroDerecho],
      [anterior.caderaIzquierda, nuevo.caderaIzquierda],
      [anterior.caderaDerecha, nuevo.caderaDerecha],
    ];
    for (final par in pares) {
      final largo = distancia(par[0]?.punto, par[1]?.punto);
      if (largo != null && largo > saltoMaximo) return true;
    }
    return false;
  }
}
