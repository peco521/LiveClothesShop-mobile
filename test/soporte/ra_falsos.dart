import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/services/camera_service.dart';

/// Cámara falsa: nunca toca el hardware.
///
/// - `codigoError` nulo y sin cámaras → estado "no se pudo acceder a la cámara".
/// - `codigoError` con un código de `CameraException` → permiso/restringido.
class CamaraServiceFalso extends CamaraService {
  const CamaraServiceFalso({this.codigoError});

  final String? codigoError;

  @override
  Future<List<CameraDescription>> disponibles() async {
    final codigo = codigoError;
    if (codigo != null && codigo.isNotEmpty) {
      throw CameraException(codigo, 'Error simulado de prueba');
    }
    return const [];
  }

  @override
  Future<CameraController> iniciar(CameraDescription descripcion) async =>
      throw UnimplementedError('CamaraServiceFalso no crea controladores');
}

/// PNG 1×1 completamente transparente (sin red ni assets) para las pruebas.
final Uint8List pngTransparente = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// Imagen de prueba: sustituye a la descarga real de la prenda.
ImageProvider proveedorImagenFalso(String url) => MemoryImage(pngTransparente);
