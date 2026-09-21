/// Contexto que CU16 recibe desde CU10: producto, variante/color e imagen.
///
/// Se construye reutilizando el detalle de CU10 (`productoDetalleProvider`), así
/// que la ruta solo necesita `idProd` + `idVar`: el probador no depende de
/// `go_router extra` (que se pierde al reconstruir la ruta).
class RaContexto {
  const RaContexto({
    required this.idProd,
    required this.descripcion,
    required this.marca,
    this.idVar,
    this.imagenUrl,
    this.color,
    this.talla,
    this.cantidad = 1,
  });

  final String idProd;

  /// Descripción de la polera (`Polera Nike Pro`).
  final String descripcion;
  final String marca;

  /// Variante seleccionada en CU10.
  final String? idVar;

  /// Imagen de ESA variante (el color elegido), no la primera del producto.
  final String? imagenUrl;

  final String? color;

  /// Talla seleccionada: solo contexto visual, CU16 no afirma que quede bien.
  final String? talla;

  /// Cantidad elegida en CU10: se conserva al volver al detalle.
  final int cantidad;

  bool get tieneImagen => (imagenUrl ?? '').trim().isNotEmpty;

  /// Línea de contexto `Negro · Talla L`.
  String get detalle {
    final partes = <String>[
      if ((color ?? '').trim().isNotEmpty) color!.trim(),
      if ((talla ?? '').trim().isNotEmpty) 'Talla ${talla!.trim()}',
    ];
    return partes.join(' · ');
  }

  @override
  String toString() =>
      'RaContexto($idProd, idVar: $idVar, color: $color, talla: $talla)';
}

/// Datos mínimos que viajan en la ruta `/producto/:id/probar`.
class RaSolicitud {
  const RaSolicitud({
    required this.idProd,
    this.idVar,
    this.talla,
    this.cantidad = 1,
  });

  final String idProd;
  final String? idVar;
  final String? talla;
  final int cantidad;

  @override
  bool operator ==(Object other) =>
      other is RaSolicitud &&
      other.idProd == idProd &&
      other.idVar == idVar &&
      other.talla == talla &&
      other.cantidad == cantidad;

  @override
  int get hashCode => Object.hash(idProd, idVar, talla, cantidad);

  @override
  String toString() => 'RaSolicitud($idProd, $idVar, $talla, $cantidad)';
}
