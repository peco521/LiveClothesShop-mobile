/// Error de API con mensaje apto para UI. Nunca incluye credenciales.
class ApiException implements Exception {
  final int status;
  final String code;

  const ApiException(this.status, this.code);

  /// Mensaje funcional en español. No expone detalles internos.
  String get userMessage {
    switch (status) {
      case 401:
        return 'Tu sesión ha expirado o no es válida. Inicia sesión nuevamente.';
      case 403:
        return 'No tienes autorización para esta operación.';
      case 404:
        return code == 'producto_no_encontrado' || code == 'prenda_no_encontrada'
            ? 'No se encontró la prenda solicitada.'
            : code == 'sucursal_no_encontrada'
                ? 'La sucursal seleccionada no existe o no está disponible.'
                : code == 'variante_no_encontrada'
                    ? 'La variante seleccionada ya no está disponible.'
                    : code == 'venta_no_encontrada'
                        ? 'La venta a pagar no existe o ya no está disponible.'
                        : code == 'pago_no_encontrado' || code == 'reserva_no_encontrada'
                            ? 'No se encontró el registro solicitado.'
                            : 'No se encontró el recurso solicitado.';
      case 409:
        return code == 'disponibilidad_insuficiente'
            ? 'No hay disponibilidad suficiente en la sucursal elegida.'
            : code == 'sucursal_inactiva'
                ? 'La sucursal seleccionada no está disponible.'
                : code == 'carrito_no_disponible'
                    ? 'No tienes un carrito activo para comprar.'
                    : code == 'venta_no_pagable'
                        ? 'La venta ya no puede pagarse.'
                        : code == 'reserva_no_cancelable'
                            ? 'La reserva ya no puede cancelarse.'
                            : 'Existe un conflicto de datos. Vuelve a intentarlo.';
      case 422:
        return code == 'horario_fuera_atencion'
            ? 'El horario solicitado está fuera de la atención de la sucursal.'
            : 'Revisa los datos enviados. No son válidos.';
      case 0:
        return 'No se pudo conectar con el servidor. Comprueba tu conexión.';
      default:
        return 'No se pudo completar la operación. Inténtalo nuevamente.';
    }
  }

  @override
  String toString() => 'ApiException($status, $code)';
}
