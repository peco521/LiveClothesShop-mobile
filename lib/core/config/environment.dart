import 'package:flutter/foundation.dart';

/// Configuración central de la app móvil.
///
/// La URL del backend NO se escribe en cada pantalla: se define aquí y puede
/// sobreescribirse en tiempo de compilación, por ejemplo:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
///
/// Valores por defecto:
///  * Emulador Android  -> http://10.0.2.2:8000/api (10.0.2.2 es el host)
///  * Resto (iOS/web/desktop) -> http://localhost:8000/api
class Environment {
  const Environment._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Backend FastAPI compartido con la web Angular (mismas APIs, sin duplicar).
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  /// El backend exige `Origin` incluido en ALLOWED_ORIGINS y la cabecera
  /// `X-CSRF-Protection: 1` en métodos que escriben. Un cliente nativo no tiene
  /// Origin propio, así que declara uno de los orígenes permitidos por el
  /// backend (por defecto http://localhost:4200, ver ALLOWED_ORIGINS en .env).
  /// Si tu backend usa otro origen, compílalo con:
  ///   --dart-define=API_ORIGIN=https://tienda.ejemplo.com
  static const String requestOrigin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://localhost:4200',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Logging de red solo en desarrollo (nunca cookies ni contraseñas).
  static bool get verboseNetworkLogs =>
      !kReleaseMode &&
      const bool.fromEnvironment('API_LOGS', defaultValue: true);
}
