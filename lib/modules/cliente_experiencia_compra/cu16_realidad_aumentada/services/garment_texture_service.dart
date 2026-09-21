import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Textura lista para el probador: imagen decodificada + bounding box real alfa.
class TexturaPrenda {
  const TexturaPrenda({
    required this.imagen,
    required this.uvBounds,
    required this.url,
    required this.tieneTransparencia,
  });

  final ui.Image imagen;

  /// Zona REAL de la prenda dentro de la imagen, normalizada `0..1`.
  ///
  /// Así una imagen de 447×447 y otra de 929×700 se comportan igual: los UV de
  /// la malla se miden sobre este rectángulo, no sobre la imagen completa.
  final Rect uvBounds;

  final String url;

  /// `false` cuando la imagen es opaca (JPG con fondo): se usa igual y se
  /// documenta la limitación.
  final bool tieneTransparencia;

  bool get esValida =>
      imagen.width > 0 &&
      imagen.height > 0 &&
      uvBounds.width > 0 &&
      uvBounds.height > 0;

  /// Matriz para `ImageShader`: lleva el espacio UV (`0..1` del bounding box) a
  /// píxeles reales de la imagen. Formato columna-mayor de `dart:ui`.
  Float64List get matrizUv {
    final ancho = imagen.width.toDouble();
    final alto = imagen.height.toDouble();
    return Float64List.fromList(<double>[
      uvBounds.width * ancho, 0, 0, 0, //
      0, uvBounds.height * alto, 0, 0, //
      0, 0, 1, 0, //
      uvBounds.left * ancho, uvBounds.top * alto, 0, 1,
    ]);
  }

  @override
  String toString() =>
      'TexturaPrenda(${imagen.width}x${imagen.height}, uv: $uvBounds, '
      'transparente: $tieneTransparencia)';
}

/// Carga la textura UNA vez por variante y calcula su bounding box alfa.
///
/// Nunca decodifica ni descarga por frame: `ImageProvider` (por ejemplo
/// `CachedNetworkImageProvider`) reaprovecha la caché de disco y memoria.
class GarmentTextureService {
  GarmentTextureService({this.maximoEnCache = 2});

  /// Alfa mínimo para considerar que un píxel pertenece a la prenda.
  static const int umbralAlfa = 24;

  /// Muestreo del análisis alfa (2 = un píxel de cada 2, suficiente y rápido).
  static const int pasoAnalisis = 2;

  final int maximoEnCache;
  final Map<String, TexturaPrenda> _cache = {};
  final List<String> _orden = [];

  TexturaPrenda? enCache(String clave) => _cache[clave];

  /// Carga (o devuelve de caché) la textura de [proveedor].
  Future<TexturaPrenda> cargar(
    ImageProvider proveedor, {
    required String clave,
  }) async {
    final guardada = _cache[clave];
    if (guardada != null) return guardada;

    final imagen = await _decodificar(proveedor);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bounds =
        boundingBoxAlfa(datos, imagen.width, imagen.height) ??
        const Rect.fromLTRB(0, 0, 1, 1);
    final completa =
        bounds.left <= 0.001 &&
        bounds.top <= 0.001 &&
        bounds.right >= 0.999 &&
        bounds.bottom >= 0.999;

    final textura = TexturaPrenda(
      imagen: imagen,
      uvBounds: bounds,
      url: clave,
      tieneTransparencia: !completa,
    );
    _guardar(clave, textura);
    return textura;
  }

  void _guardar(String clave, TexturaPrenda textura) {
    _cache[clave] = textura;
    _orden.remove(clave);
    _orden.add(clave);
    while (_orden.length > maximoEnCache) {
      final vieja = _orden.removeAt(0);
      final textura = _cache.remove(vieja);
      textura?.imagen.dispose();
    }
  }

  /// Libera la textura de una clave (por ejemplo al salir del probador).
  void liberarUrl(String clave) {
    _orden.remove(clave);
    _cache.remove(clave)?.imagen.dispose();
  }

  /// Libera todas las texturas: se llama al cerrar CU16.
  void liberar() {
    for (final textura in _cache.values) {
      textura.imagen.dispose();
    }
    _cache.clear();
    _orden.clear();
  }

  Future<ui.Image> _decodificar(ImageProvider proveedor) {
    final completer = Completer<ui.Image>();
    final stream = proveedor.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (informacion, _) {
        if (!completer.isCompleted) completer.complete(informacion.image);
        stream.removeListener(listener);
      },
      onError: (error, pila) {
        if (!completer.isCompleted) completer.completeError(error, pila);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Bounding box del contenido no transparente, normalizado `0..1`.
  ///
  /// Devuelve `null` cuando no hay ningún píxel opaco o no hay datos.
  static Rect? boundingBoxAlfa(
    ByteData? datos,
    int ancho,
    int alto, {
    int umbral = umbralAlfa,
    int paso = pasoAnalisis,
  }) {
    if (datos == null || ancho <= 0 || alto <= 0) return null;
    final bytes = datos.buffer.asUint8List(
      datos.offsetInBytes,
      datos.lengthInBytes,
    );
    var minX = ancho;
    var minY = alto;
    var maxX = -1;
    var maxY = -1;
    final salto = paso < 1 ? 1 : paso;
    for (var y = 0; y < alto; y += salto) {
      final fila = y * ancho;
      for (var x = 0; x < ancho; x += salto) {
        final alfa = bytes[(fila + x) * 4 + 3];
        if (alfa <= umbral) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0 || maxY < 0) return null;
    // El muestreo con `paso` puede dejar hasta `paso` píxeles sin revisar: se
    // extiende el borde derecho/inferior para no recortar la prenda.
    final izquierda = minX / ancho;
    final arriba = minY / alto;
    final derecha = ((maxX + salto).clamp(0, ancho)) / ancho;
    final abajo = ((maxY + salto).clamp(0, alto)) / alto;
    final rect = Rect.fromLTRB(izquierda, arriba, derecha, abajo);
    if (rect.width <= 0 || rect.height <= 0) return null;
    return rect;
  }
}
