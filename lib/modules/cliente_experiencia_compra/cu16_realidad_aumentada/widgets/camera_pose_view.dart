import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/garment_mesh.dart';
import '../models/pose_frame.dart';
import '../models/ra_estado.dart';
import '../painters/garment_mesh_painter.dart';
import '../providers/realidad_aumentada_provider.dart';
import '../services/garment_mesh_service.dart';
import '../services/garment_texture_service.dart';
import '../services/pose_smoother.dart';
import '../utils/pose_coordinates.dart';

/// Cámara frontal + malla de la polera encima (CU16).
///
/// Mantiene el estado de la pose en un `ValueNotifier` LOCAL: el painter se
/// repinta sin reconstruir widgets y sin publicar estado global por frame.
class CameraPoseView extends ConsumerStatefulWidget {
  const CameraPoseView({
    super.key,
    required this.camara,
    required this.textura,
    required this.mallas,
    required this.onEstadoPose,
  });

  final CamaraRaEstado camara;
  final TexturaPrenda textura;
  final GarmentMeshService mallas;

  /// Notifica cambios de estado de pose hacia la pantalla (solo al cambiar).
  final ValueChanged<RaEstadoPose> onEstadoPose;

  @override
  ConsumerState<CameraPoseView> createState() => _CameraPoseViewState();
}

class _CameraPoseViewState extends ConsumerState<CameraPoseView>
    with WidgetsBindingObserver {
  /// Malla vigente: la consume el painter con `repaint`.
  final ValueNotifier<GarmentMesh?> _malla = ValueNotifier<GarmentMesh?>(null);
  final PoseSmoother _suavizador = PoseSmoother();

  /// Control obligatorio: nunca se procesan dos frames a la vez.
  bool _procesando = false;

  /// Inferencias por segundo (no hace falta inferir a 30 FPS).
  static const int inferenciasPorSegundo = 12;

  int _framesProcesados = 0;
  DateTime _ultimaInferencia = DateTime.fromMillisecondsSinceEpoch(0);
  Size _lienzo = Size.zero;
  RaEstadoPose _estado = RaEstadoPose.buscando;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarStream();
  }

  @override
  void didUpdateWidget(covariant CameraPoseView anterior) {
    super.didUpdateWidget(anterior);
    final cambioCamara =
        anterior.camara.controlador != widget.camara.controlador;
    final cambioTextura = anterior.textura.url != widget.textura.url;
    if (cambioCamara || cambioTextura) {
      // Cambió la cámara o la prenda: se olvida el suavizado anterior.
      _suavizador.reset();
      _malla.value = null;
      _iniciarStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detenerStream();
    _malla.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Al fondo se detiene el stream (y con él ML Kit).
        _detenerStream();
      case AppLifecycleState.resumed:
        _reanudar();
    }
  }

  Future<void> _iniciarStream() async {
    final controlador = widget.camara.controlador;
    if (controlador == null || !controlador.value.isInitialized) return;
    if (controlador.value.isStreamingImages) return;
    try {
      await controlador.startImageStream(_onFrame);
    } catch (_) {
      // El preview sigue visible aunque el stream no esté disponible.
    }
  }

  Future<void> _detenerStream() async {
    final controlador = widget.camara.controlador;
    if (controlador == null) return;
    try {
      if (controlador.value.isStreamingImages) {
        await controlador.stopImageStream();
      }
    } catch (_) {
      // Nada que hacer: la cámara ya estaba detenida.
    }
  }

  /// Reanudación segura tras volver del segundo plano.
  Future<void> _reanudar() async {
    final controlador = widget.camara.controlador;
    if (controlador == null || !controlador.value.isInitialized) {
      // Android suele revocar la cámara en segundo plano: se recrea.
      await ref.read(camaraRaProvider.notifier).reiniciar();
      return;
    }
    _suavizador.reset();
    await _iniciarStream();
  }

  /// Tamaño (rotado) del último frame recibido: se usa para las coordenadas y
  /// como respaldo del layout mientras el plugin no reporta `previewSize`.
  Size _tamanoImagenRotada = Size.zero;

  /// Frame de la cámara. Si el detector está ocupado, el frame se DESCARTA.
  Future<void> _onFrame(CameraImage imagen) async {
    if (!mounted || _procesando) return;
    final ahora = DateTime.now();
    if (ahora.difference(_ultimaInferencia).inMilliseconds <
        1000 ~/ inferenciasPorSegundo) {
      return;
    }
    final controlador = widget.camara.controlador;
    final lienzo = _lienzo;
    if (controlador == null || lienzo.isEmpty) return;

    _procesando = true;
    final primero = _framesProcesados == 0;
    try {
      final grados = PoseCoordinates.gradosParaInputImage(
        sensorOrientation: widget.camara.orientacionSensor,
        dispositivo: controlador.value.deviceOrientation,
        esFrontal: widget.camara.esFrontal,
      );
      _tamanoImagenRotada = PoseCoordinates.tamanoRotado(
        Size(imagen.width.toDouble(), imagen.height.toDouble()),
        grados,
      );
      final pose = await ref
          .read(poseDetectionServiceProvider)
          .detectar(imagen: imagen, gradosRotacion: grados);
      if (!mounted) return;
      final suave = _suavizador.suavizar(pose ?? const PoseFrame());
      final malla = suave == null
          ? null
          : widget.mallas.construir(
              pose: suave,
              coordenadas: PoseCoordinates(
                tamanoFrame: _tamanoImagenRotada,
                tamanoLienzo: lienzo,
                espejo: widget.camara.esFrontal,
              ),
            );
      _malla.value = malla;
      _framesProcesados++;
      _publicarEstado(
        malla == null ? RaEstadoPose.sinTorso : RaEstadoPose.activa,
      );
    } catch (_) {
      if (mounted) _publicarEstado(RaEstadoPose.sinTorso);
    } finally {
      _ultimaInferencia = ahora;
      _procesando = false;
      if (primero && mounted) setState(() {});
    }
  }

  /// Solo se notifica al CAMBIAR: nada de 30 estados por segundo.
  void _publicarEstado(RaEstadoPose nuevo) {
    if (_estado == nuevo) return;
    _estado = nuevo;
    widget.onEstadoPose(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final controlador = widget.camara.controlador;
    final tamanoPreview = widget.camara.tamanoPreview.isEmpty
        ? _tamanoImagenRotada
        : PoseCoordinates.tamanoRotado(
            widget.camara.tamanoPreview,
            widget.camara.orientacionSensor,
          );

    return LayoutBuilder(
      builder: (context, restricciones) {
        // El lienzo es la caja donde se dibuja todo: preview y malla comparten
        // el mismo sistema de coordenadas.
        _lienzo = Size(restricciones.maxWidth, restricciones.maxHeight);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controlador != null && !tamanoPreview.isEmpty)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: tamanoPreview.width,
                    height: tamanoPreview.height,
                    child: CameraPreview(controlador),
                  ),
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: GarmentMeshPainter(
                    malla: _malla,
                    textura: widget.textura,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
