import 'package:camera/camera.dart';

/// Acceso a la cámara aislado detrás de esta clase.
///
/// En pruebas se sustituye por un doble (`CamaraServiceFalso`), así CU16 se
/// prueba sin hardware y sin excepciones de plugin.
class CamaraService {
  const CamaraService();

  /// Resolución equilibrada para tiempo real: no se usa la máxima.
  static const ResolutionPreset resolucion = ResolutionPreset.medium;

  /// NV21 llega en un solo plano y es formato directo para ML Kit.
  static const ImageFormatGroup formato = ImageFormatGroup.nv21;

  Future<List<CameraDescription>> disponibles() => availableCameras();

  /// Cámara prioritaria: la frontal si existe; si no, la primera disponible.
  static CameraDescription? elegir(List<CameraDescription> camaras) {
    if (camaras.isEmpty) return null;
    for (final camara in camaras) {
      if (camara.lensDirection == CameraLensDirection.front) return camara;
    }
    return camaras.first;
  }

  Future<CameraController> iniciar(CameraDescription descripcion) async {
    final controlador = CameraController(
      descripcion,
      resolucion,
      enableAudio: false,
      imageFormatGroup: formato,
    );
    await controlador.initialize();
    return controlador;
  }
}
