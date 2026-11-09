import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../../cu10_consultar_prendas/models/catalogo.dart';
import '../../cu12_carrito/data/carrito_api.dart';
import '../models/vestidor_models.dart';
import '../services/pose_tracker_service.dart';
import '../widgets/clothing_overlay_painter.dart';

/// Pantalla del Vestidor Virtual AR (CU23).
/// Permite al cliente probarse prendas en tiempo real sobre su cuerpo utilizando
/// la cámara de su dispositivo móvil y detección de puntos anatómicos corporales.
class VestidorScreen extends StatefulWidget {
  final ProductoDetalle producto;
  final VarianteDetalle? varianteInicial;
  final CarritoApi? carritoApi;

  const VestidorScreen({
    super.key,
    required this.producto,
    this.varianteInicial,
    this.carritoApi,
  });

  @override
  State<VestidorScreen> createState() => _VestidorScreenState();
}

class _VestidorScreenState extends State<VestidorScreen>
    with WidgetsBindingObserver {
  late VarianteDetalle _varianteActual;
  late GarmentFittingConfig _config;
  late PoseTrackerService _poseService;

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;

  FittingTrackingStatus _status = FittingTrackingStatus.iniciando;
  BodyPoseEstimate? _currentPose;
  Size _imageSize = Size.zero;
  String? _errorMessage;
  bool _agregandoCarrito = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _varianteActual = widget.varianteInicial ??
        (widget.producto.variantes.isNotEmpty
            ? widget.producto.variantes.first
            : const VarianteDetalle(
                id: '',
                sku: '',
                precio: 0,
                imagen: null,
                talla: TallaDetalle(id: 0, descripcion: 'M'),
                colores: [],
              ));

    _config = GarmentFittingConfig(
      sizeScaleMultiplier: GarmentFittingConfig.scaleFromTalla(
        _varianteActual.talla.descripcion,
      ),
    );

    _poseService = PoseTrackerService();
    _iniciarCamara();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _detenerCamara();
    } else if (state == AppLifecycleState.resumed) {
      _iniciarCamara();
    }
  }

  Future<void> _iniciarCamara() async {
    setState(() {
      _status = FittingTrackingStatus.iniciando;
      _errorMessage = null;
    });

    try {
      final permStatus = await Permission.camera.request();
      if (!permStatus.isGranted) {
        if (!mounted) return;
        setState(() => _status = FittingTrackingStatus.sinPermiso);
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _status = FittingTrackingStatus.camaraNoDisponible);
        return;
      }

      // Priorizar cámara frontal para efecto espejo en vestidor virtual
      int frontIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex >= 0 ? frontIndex : 0;

      await _inicializarControlador(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = FittingTrackingStatus.errorSensor;
        _errorMessage = 'No se pudo acceder a la cámara: $e';
      });
    }
  }

  Future<void> _inicializarControlador(CameraDescription camera) async {
    final prev = _cameraController;
    if (prev != null) {
      await prev.dispose();
    }

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      _imageSize = Size(
        controller.value.previewSize?.height ?? 720,
        controller.value.previewSize?.width ?? 1280,
      );

      setState(() => _status = FittingTrackingStatus.buscandoPersona);

      await controller.startImageStream((CameraImage image) {
        _procesarFrame(image, camera);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = FittingTrackingStatus.errorSensor;
        _errorMessage = 'Fallo al inicializar transmisión de video: $e';
      });
    }
  }

  void _procesarFrame(CameraImage image, CameraDescription camera) async {
    final estimate = await _poseService.processFrame(image, camera);
    if (!mounted) return;

    if (estimate != null && estimate.hasTorso) {
      setState(() {
        _currentPose = estimate;
        _status = FittingTrackingStatus.cuerpoDetectado;
      });
    } else {
      if (_status == FittingTrackingStatus.cuerpoDetectado) {
        setState(() {
          _status = FittingTrackingStatus.buscandoPersona;
          _currentPose = null;
        });
      }
    }
  }

  Future<void> _cambiarCamara() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _inicializarControlador(_cameras[_selectedCameraIndex]);
  }

  Future<void> _detenerCamara() async {
    try {
      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController?.stopImageStream();
      }
      await _cameraController?.dispose();
      _cameraController = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detenerCamara();
    _poseService.dispose();
    super.dispose();
  }

  Color _obtenerColorVariante(VarianteDetalle v) {
    if (v.colores.isNotEmpty) {
      final hex = v.colores.first.hex.replaceAll('#', '');
      try {
        if (hex.length == 6) {
          return Color(int.parse('0xFF$hex'));
        }
      } catch (_) {}
    }
    // Color por defecto sobrio si no tiene hex válido
    return const Color(0xFF2C3E50);
  }

  void _seleccionarVariante(VarianteDetalle v) {
    setState(() {
      _varianteActual = v;
      _config = _config.copyWith(
        sizeScaleMultiplier: GarmentFittingConfig.scaleFromTalla(
          v.talla.descripcion,
        ),
      );
    });
  }

  CarritoApi get _carrito {
    if (widget.carritoApi != null) return widget.carritoApi!;
    return CarritoApi(
      credential: () => context.read<SessionState>().credentialForApi,
    );
  }

  Future<void> _agregarAlCarrito() async {
    if (_varianteActual.id.isEmpty || _agregandoCarrito) return;
    setState(() => _agregandoCarrito = true);
    try {
      await _carrito.agregar(_varianteActual.id, 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prenda agregada al carrito: Talla ${_varianteActual.talla.descripcion}.',
          ),
          action: SnackBarAction(
            label: 'Ver carrito',
            onPressed: () => Navigator.of(context).pushNamed('/tienda/carrito'),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    } finally {
      if (mounted) setState(() => _agregandoCarrito = false);
    }
  }

  void _irANuevaReserva() {
    if (_varianteActual.id.isEmpty) return;
    Navigator.of(context).pushNamed(
      '/tienda/reservas/nueva',
      arguments: {'idVar': _varianteActual.id, 'cantidad': 1},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFront =
        _cameraController?.description.lensDirection ==
        CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          'Vestidor Virtual · ${widget.producto.descripcion}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Cambiar cámara (Frontal/Trasera)',
              onPressed: _cambiarCamara,
            ),
          IconButton(
            icon: Icon(
              _config.showLandmarkGuide
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
            tooltip: 'Guía anatómica de landmarks',
            onPressed: () => setState(() {
              _config = _config.copyWith(
                showLandmarkGuide: !_config.showLandmarkGuide,
              );
            }),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Vista de cámara y capa AR de la prenda
          _construirCapaCamaraYPrenda(isFront),

          // 2. Banner de transparencia de alcance
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _construirBannerAlcance(),
          ),

          // 3. Indicador de estado de detección anatómica
          if (_status == FittingTrackingStatus.buscandoPersona)
            Positioned(
              top: 70,
              left: 24,
              right: 24,
              child: _construirAlertaBuscandoPersona(),
            ),

          // 4. Panel inferior de selección de variantes y acciones
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _construirPanelInferior(),
          ),
        ],
      ),
    );
  }

  Widget _construirCapaCamaraYPrenda(bool isFront) {
    if (_status == FittingTrackingStatus.sinPermiso) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Permiso de cámara necesario',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'El vestidor virtual requiere acceso a la cámara para detectar tu postura y superponer la prenda sobre tu cuerpo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _iniciarCamara,
                icon: const Icon(Icons.refresh),
                label: const Text('Conceder permiso'),
              ),
            ],
          ),
        ),
      );
    }

    if (_status == FittingTrackingStatus.camaraNoDisponible ||
        _status == FittingTrackingStatus.errorSensor) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Cámara no disponible en este dispositivo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver al detalle'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Vista previa nativa de la cámara
              CameraPreview(controller),

              // Superposición geométrica de la prenda según postura humana
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: ClothingOverlayPainter(
                  pose: _currentPose,
                  cameraImageSize: _imageSize,
                  isFrontCamera: isFront,
                  garmentColor: _obtenerColorVariante(_varianteActual),
                  categoryName: widget.producto.categoria,
                  config: _config,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _construirBannerAlcance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.cyanAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Superposición AR 2D paramétrica sobre torso. La prueba no altera stock ni genera reservas.',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirAlertaBuscandoPersona() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.accessibility, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Ubícate frente a la cámara mostrando torso y hombros.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPanelInferior() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de variantes (Talla, Color, Precio)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Variante: Talla ${_varianteActual.talla.descripcion} · Bs ${_varianteActual.precio.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Ajuste: ${(_config.totalScale * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Carrusel de selección de variantes
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.producto.variantes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final v = widget.producto.variantes[i];
                final seleccionada = v.id == _varianteActual.id;
                final col = _obtenerColorVariante(v);

                return ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: col, radius: 10),
                  label: Text('${v.talla.descripcion} (Bs ${v.precio.toStringAsFixed(0)})'),
                  selected: seleccionada,
                  onSelected: (_) => _seleccionarVariante(v),
                );
              },
            ),
          ),

          // Slider de ajuste manual fino de escala/calce
          Row(
            children: [
              const Icon(Icons.straighten, size: 18),
              Expanded(
                child: Slider(
                  value: _config.userScaleOffset,
                  min: -0.2,
                  max: 0.2,
                  divisions: 8,
                  label: '${(_config.userScaleOffset * 100).toInt()}%',
                  onChanged: (val) => setState(() {
                    _config = _config.copyWith(userScaleOffset: val);
                  }),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt, size: 20),
                tooltip: 'Restablecer escala anatómica',
                onPressed: () => setState(() {
                  _config = _config.copyWith(userScaleOffset: 0.0);
                }),
              ),
            ],
          ),

          // Botones de acción directa (CU11 y CU12)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _irANuevaReserva,
                  icon: const Icon(Icons.event_note, size: 18),
                  label: const Text('Reservar (CU11)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _agregandoCarrito ? null : _agregarAlCarrito,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(_agregandoCarrito ? 'Agregando…' : 'Al carrito (CU12)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
