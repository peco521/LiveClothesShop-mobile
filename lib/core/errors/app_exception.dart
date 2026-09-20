/// Errores de red normalizados de toda la app: la UI nunca muestra detalles
/// técnicos crudos, solo mensajes ya listos para el cliente.
enum AppErrorKind {
  unauthorized,
  forbidden,
  notFound,
  conflict,
  invalid,
  server,
  unavailable,
  network,
  unknown,
}

class AppException implements Exception {
  const AppException(this.kind, this.message, {this.code, this.statusCode});

  final AppErrorKind kind;

  /// Mensaje listo para mostrar en pantalla.
  final String message;

  /// Código de negocio del backend (`error.code`), por ejemplo
  /// `compra_no_encontrada`. Se usa para lógica, nunca se muestra crudo.
  final String? code;
  final int? statusCode;

  bool get isUnauthorized => kind == AppErrorKind.unauthorized;

  /// Traduce la respuesta del backend (contrato `{"error": {"code","message"}}`).
  factory AppException.fromResponse(int? status, Object? body) {
    final map = body is Map ? body : const <String, dynamic>{};
    final error = map['error'] is Map
        ? map['error'] as Map
        : const <String, dynamic>{};
    final kind = switch (status) {
      401 => AppErrorKind.unauthorized,
      403 => AppErrorKind.forbidden,
      404 => AppErrorKind.notFound,
      409 => AppErrorKind.conflict,
      422 => AppErrorKind.invalid,
      503 => AppErrorKind.unavailable,
      final int value when value >= 500 => AppErrorKind.server,
      _ => AppErrorKind.unknown,
    };
    return AppException(
      kind,
      messageFor(kind),
      code: error['code']?.toString(),
      statusCode: status,
    );
  }

  factory AppException.network([Object? cause]) => AppException(
    AppErrorKind.network,
    'No se pudo conectar con la tienda. Revisa tu conexión e inténtalo de nuevo.',
    code: cause?.toString(),
  );

  static String messageFor(AppErrorKind kind) => switch (kind) {
    AppErrorKind.unauthorized => 'Tu sesión expiró. Inicia sesión nuevamente.',
    AppErrorKind.forbidden => 'No tienes autorización para esta acción.',
    AppErrorKind.notFound => 'No encontramos la información solicitada.',
    AppErrorKind.conflict =>
      'La operación no se pudo completar por el estado actual del pedido.',
    AppErrorKind.invalid =>
      'Revisa los datos ingresados: hay valores no válidos.',
    AppErrorKind.server =>
      'Ocurrió un error en la tienda. Inténtalo más tarde.',
    AppErrorKind.unavailable =>
      'El servicio no está disponible en este momento. Inténtalo más tarde.',
    AppErrorKind.network =>
      'No se pudo conectar con la tienda. Revisa tu conexión.',
    AppErrorKind.unknown =>
      'No pudimos completar la operación. Inténtalo nuevamente.',
  };

  @override
  String toString() => 'AppException($kind, $statusCode, $code)';
}

/// Mensaje seguro para la UI a partir de cualquier error capturado.
String mensajeDeError(Object? error) => error is AppException
    ? error.message
    : AppException.messageFor(AppErrorKind.unknown);
