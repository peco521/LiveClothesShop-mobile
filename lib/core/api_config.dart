/// Configuración central de la API (sin secretos en código).
class ApiConfig {
  /// Base del backend. En emulador Android usar http://10.0.2.2:8001.
  /// Se puede sobreescribir con --dart-define=API_BASE_URL=...
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );

  /// Origin enviado en mutaciones POST. El backend exige un Origin exacto
  /// dentro de ALLOWED_ORIGINS + cabecera X-CSRF-Protection.
  /// En producción debe configurarse un origen propio de la app móvil.
  static const origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://localhost:4200',
  );

  static const cookieName = 'liveclothes_session';
  static const credentialStorageKey = 'liveclothes_credential';
}
