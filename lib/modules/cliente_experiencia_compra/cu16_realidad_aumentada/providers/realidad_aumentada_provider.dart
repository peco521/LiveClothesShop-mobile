import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cu10_consultar_prendas/models/producto.dart';
import '../../cu10_consultar_prendas/providers/catalogo_provider.dart';
import '../models/ra_contexto.dart';
import '../models/ra_estado.dart';
import '../services/camera_service.dart';
import '../services/garment_mesh_service.dart';
import '../services/garment_texture_service.dart';
import '../services/pose_detection_service.dart';

/// ¿Esta plataforma puede usar el probador virtual?
///
/// CU16 está pensado para Android (y iOS). En web/escritorio se muestra un
/// mensaje claro en vez de intentar abrir una cámara que no existe.
bool get plataformaRaSoportada =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// La misma comprobación, pero como provider: las pruebas pueden simular una
/// plataforma soportada (Android) o una que no lo es (escritorio/web).
final plataformaRaSoportadaProvider = Provider<bool>(
  (ref) => plataformaRaSoportada,
);

/// Servicios de CU16 declarados como providers para poder sustituirlos en
/// pruebas (nunca se toca el hardware desde `flutter test`).
final camaraServiceProvider = Provider<CamaraService>(
  (ref) => const CamaraService(),
);

final garmentMeshServiceProvider = Provider<GarmentMeshService>(
  (ref) => const GarmentMeshService(),
);

final garmentTextureServiceProvider = Provider<GarmentTextureService>((ref) {
  final servicio = GarmentTextureService();
  ref.onDispose(servicio.liberar);
  return servicio;
});

final poseDetectionServiceProvider = Provider<PoseDetectionService>((ref) {
  final servicio = PoseDetectionService();
  ref.onDispose(servicio.cerrar);
  return servicio;
});

/// Cámara del probador: frontal, resolución media y NV21 para ML Kit.
final camaraRaProvider =
    AsyncNotifierProvider<CamaraRaController, CamaraRaEstado>(
      CamaraRaController.new,
    );

class CamaraRaController extends AsyncNotifier<CamaraRaEstado> {
  @override
  Future<CamaraRaEstado> build() async {
    if (!ref.watch(plataformaRaSoportadaProvider)) {
      return const CamaraRaEstado.error(RaErrorCamara.noSoportado);
    }
    final servicio = ref.read(camaraServiceProvider);
    try {
      final camaras = await servicio.disponibles();
      final elegida = CamaraService.elegir(camaras);
      if (elegida == null) {
        return const CamaraRaEstado.error(RaErrorCamara.sinCamara);
      }
      final controlador = await servicio.iniciar(elegida);
      // El controlador se libera solo: `onDispose` corre antes de cada rebuild
      // (cambio de cámara, reinicio tras segundo plano o salida de CU16).
      ref.onDispose(() {
        controlador.dispose();
      });
      return CamaraRaEstado(controlador: controlador, descripcion: elegida);
    } on CameraException catch (error) {
      return CamaraRaEstado.error(traducirErrorCamara(error.code));
    } catch (_) {
      return const CamaraRaEstado.error(RaErrorCamara.desconocido);
    }
  }

  /// Reinicia la cámara al volver del segundo plano (reanudación segura).
  Future<void> reiniciar() async {
    ref.invalidateSelf();
    await future;
  }

  /// Códigos de error de la cámara → mensajes de CU16.
  static RaErrorCamara traducirErrorCamara(String codigo) => switch (codigo) {
    'CameraAccessDenied' => RaErrorCamara.permisoDenegado,
    'CameraAccessDeniedWithoutPrompt' => RaErrorCamara.permisoBloqueado,
    'CameraAccessRestricted' => RaErrorCamara.restringido,
    _ => RaErrorCamara.desconocido,
  };
}

/// Cómo se obtiene la imagen de la prenda.
///
/// En producción es `CachedNetworkImageProvider` (caché en disco de
/// `cached_network_image`, ya usada por CU10); en pruebas se sustituye por
/// `MemoryImage` para no depender de la red.
final proveedorImagenRaProvider = Provider<ImageProvider Function(String)>(
  (ref) =>
      (url) => CachedNetworkImageProvider(url),
);

/// Textura de la polera: se carga UNA vez por URL (variante/color).
final texturaRaProvider = FutureProvider.family<TexturaPrenda, String>((
  ref,
  url,
) {
  final servicio = ref.watch(garmentTextureServiceProvider);
  final proveedor = ref.watch(proveedorImagenRaProvider)(url);
  return servicio.cargar(proveedor, clave: url);
});

/// Contexto de CU16 reconstruido desde CU10 con `idProd` + `idVar`.
///
/// No depende de `go_router extra`: si la ruta se reconstruye, se vuelve a
/// resolver la variante y su imagen desde el detalle del catálogo.
final contextoRaProvider = FutureProvider.family<RaContexto, RaSolicitud>((
  ref,
  solicitud,
) async {
  final detalle = await ref.watch(
    productoDetalleProvider(solicitud.idProd).future,
  );
  final variante = varianteElegida(detalle, solicitud.idVar);
  return RaContexto(
    idProd: detalle.idProd,
    descripcion: detalle.descripcion,
    marca: detalle.marca.nombre,
    idVar: variante?.idVariante,
    imagenUrl: urlImagenVariante(ref, detalle.idProd, variante),
    color: coloresDe(variante),
    talla: solicitud.talla ?? variante?.talla.descripcion,
    cantidad: solicitud.cantidad,
  );
});

/// Variante pedida por la ruta; sin `idVar` se usa la primera disponible
/// (misma regla que CU10).
VarianteDetalle? varianteElegida(ProductoDetalle detalle, String? idVar) {
  if (detalle.variantes.isEmpty) return null;
  final buscada = idVar?.trim() ?? '';
  if (buscada.isNotEmpty) {
    for (final variante in detalle.variantes) {
      if (variante.idVariante == buscada) return variante;
    }
  }
  return detalle.variantes.firstWhere(
    (variante) => detalle.disponibleEn(variante.idVariante),
    orElse: () => detalle.variantes.first,
  );
}

/// Colores de la variante, por ejemplo `Negro / Rojo`.
String? coloresDe(VarianteDetalle? variante) {
  final colores = variante?.colores
      .map((color) => color.descripcion.trim())
      .where((descripcion) => descripcion.isNotEmpty)
      .join(' / ');
  return (colores == null || colores.isEmpty) ? null : colores;
}

/// Imagen de la VARIANTE seleccionada.
///
/// CU10 entrega una imagen por variante (subida a Cloudinary desde CU18). Si la
/// variante no tiene imagen propia, se reutiliza la del producto en el listado
/// del catálogo: nunca se inventa una imagen.
String? urlImagenVariante(Ref ref, String idProd, VarianteDetalle? variante) {
  final propia = variante?.imagen?.trim();
  if (propia != null && propia.isNotEmpty) return propia;
  final listado = ref.read(catalogoProvider).asData?.value;
  if (listado == null) return null;
  for (final item in listado.items) {
    if (item.idProd != idProd) continue;
    final respaldo = item.imagen?.trim();
    if (respaldo != null && respaldo.isNotEmpty) return respaldo;
  }
  return null;
}
