import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../models/ra_contexto.dart';
import '../models/ra_estado.dart';
import '../providers/realidad_aumentada_provider.dart';
import '../services/garment_texture_service.dart';
import '../widgets/camera_pose_view.dart';
import '../widgets/ra_controls.dart';
import '../widgets/ra_status_overlay.dart';

/// CU16 — Probador virtual con realidad aumentada (2D).
///
/// Solo prueba visualmente la prenda: no agrega al carrito, no compra, no
/// reserva, no cambia inventario y no afirma que la talla sea la correcta.
class ProbadorRaScreen extends ConsumerStatefulWidget {
  const ProbadorRaScreen({
    super.key,
    required this.idProd,
    this.idVar,
    this.talla,
    this.cantidad = 1,
  });

  static const String routePath = '/producto/:id/probar';

  final String idProd;
  final String? idVar;
  final String? talla;
  final int cantidad;

  /// Ruta de CU16 conservando variante, talla y cantidad de CU10.
  static String ruta({
    required String idProd,
    String? idVar,
    String? talla,
    int cantidad = 1,
  }) {
    final parametros = <String, String>{
      if ((idVar ?? '').trim().isNotEmpty) 'idVar': idVar!.trim(),
      if ((talla ?? '').trim().isNotEmpty) 'talla': talla!.trim(),
      if (cantidad > 1) 'cantidad': '$cantidad',
    };
    final consulta = Uri(queryParameters: parametros).query;
    final ruta = '/producto/${Uri.encodeComponent(idProd)}/probar';
    return consulta.isEmpty ? ruta : '$ruta?$consulta';
  }

  @override
  ConsumerState<ProbadorRaScreen> createState() => _ProbadorRaScreenState();
}

class _ProbadorRaScreenState extends ConsumerState<ProbadorRaScreen> {
  RaEstadoPose _estadoPose = RaEstadoPose.buscando;

  RaSolicitud get _solicitud => RaSolicitud(
    idProd: widget.idProd,
    idVar: widget.idVar,
    talla: widget.talla,
    cantidad: widget.cantidad,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Probador virtual')),
      body: !ref.watch(plataformaRaSoportadaProvider)
          ? _aviso(RaErrorCamara.noSoportado.mensaje)
          : ref
                .watch(contextoRaProvider(_solicitud))
                .when(
                  loading: () => const LoadingView(
                    message: 'Preparando el probador virtual…',
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(AppTheme.gapLarge),
                    child: ErrorView(
                      message: mensajeDeError(error),
                      onRetry: () =>
                          ref.invalidate(contextoRaProvider(_solicitud)),
                    ),
                  ),
                  data: _contenido,
                ),
    );
  }

  Widget _contenido(RaContexto contexto) {
    if (!contexto.tieneImagen) {
      // Sin imagen no se inventa nada: se explica y se puede volver.
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.gapLarge),
                child: Text(
                  RaErrorCamara.sinImagen.mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          ),
          RaControls(contexto: contexto, onVolver: _volver),
        ],
      );
    }

    // La cámara se resuelve ANTES que la textura: sus errores (permiso, sin
    // cámara, plataforma) se explican de inmediato sin depender de la imagen.
    return ref
        .watch(camaraRaProvider)
        .when(
          loading: () => const LoadingView(message: 'Abriendo la cámara…'),
          error: (error, _) => _aviso(RaErrorCamara.desconocido.mensaje),
          data: (camara) {
            final problema = camara.error;
            if (problema != null) {
              return _aviso(problema.mensaje, error: problema);
            }
            final url = contexto.imagenUrl!;
            return ref
                .watch(texturaRaProvider(url))
                .when(
                  loading: () =>
                      const LoadingView(message: 'Preparando la prenda…'),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(AppTheme.gapLarge),
                    child: ErrorView(
                      message: 'No pudimos cargar la imagen de esta polera.',
                      onRetry: () => ref.invalidate(texturaRaProvider(url)),
                    ),
                  ),
                  data: (prenda) => _camara(contexto, camara, prenda),
                );
          },
        );
  }

  /// Cámara + malla sobre el preview, con la barra inferior de CU16.
  Widget _camara(
    RaContexto contexto,
    CamaraRaEstado camara,
    TexturaPrenda prenda,
  ) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPoseView(
                camara: camara,
                textura: prenda,
                mallas: ref.watch(garmentMeshServiceProvider),
                onEstadoPose: _actualizarEstadoPose,
              ),
              Positioned(
                top: AppTheme.gap,
                left: AppTheme.gap,
                right: AppTheme.gap,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RaStatusOverlay(estado: _estadoPose),
                ),
              ),
            ],
          ),
        ),
        RaControls(contexto: contexto, onVolver: _volver),
      ],
    );
  }

  void _actualizarEstadoPose(RaEstadoPose nuevo) {
    if (!mounted || _estadoPose == nuevo) return;
    setState(() => _estadoPose = nuevo);
  }

  /// Nunca se deja la pantalla negra sin explicación: mensaje + salida.
  Widget _aviso(String mensaje, {RaErrorCamara? error}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.gapLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.gapLarge),
            if (error != null && error != RaErrorCamara.noSoportado)
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(camaraRaProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            if (error != null && error != RaErrorCamara.noSoportado)
              const SizedBox(height: AppTheme.gap),
            OutlinedButton.icon(
              onPressed: _volver,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al producto'),
            ),
          ],
        ),
      ),
    );
  }

  /// Cerrar CU16 NO agrega nada al carrito: solo vuelve al detalle de CU10.
  void _volver() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/producto/${widget.idProd}');
  }
}
