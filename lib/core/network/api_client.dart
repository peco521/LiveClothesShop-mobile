import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/environment.dart';
import '../errors/app_exception.dart';

/// Cliente HTTP único de la app (Dio + cookie_jar + interceptor de cookies).
///
/// Toda la app usa esta instancia: la sesión del backend es una cookie HttpOnly
/// (`liveclothes_session`, path `/api`), así que la cookie se guarda y se
/// reenvía automáticamente. Nunca se combina con `Authorization: Bearer`: el
/// backend responde 401 si llegan cookie y bearer a la vez.
class ApiClient {
  ApiClient._(this.dio, this.cookies, this._unauthorized);

  final Dio dio;
  final CookieJar cookies;
  final StreamController<void> _unauthorized;

  /// Se emite cuando el backend responde 401 (sesión expirada) para que la capa
  /// de sesión cierre el estado y el router redirija al login.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  static Future<ApiClient> create({CookieJar? cookieJar}) async {
    final jar = cookieJar ?? await _persistentCookieJar();
    final dio = Dio(
      BaseOptions(
        baseUrl: Environment.apiBaseUrl,
        connectTimeout: Environment.connectTimeout,
        receiveTimeout: Environment.receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );
    final unauthorized = StreamController<void>.broadcast();
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(BackendSecurityInterceptor());
    if (Environment.verboseNetworkLogs) {
      dio.interceptors.add(SafeLogInterceptor());
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401) unauthorized.add(null);
          handler.next(error);
        },
      ),
    );
    return ApiClient._(dio, jar, unauthorized);
  }

  /// Cookie jar persistente: la sesión sobrevive al reinicio de la app sin que
  /// Dart lea nunca el valor de la cookie HttpOnly.
  static Future<CookieJar> _persistentCookieJar() async {
    final dir = await getApplicationSupportDirectory();
    return PersistCookieJar(
      storage: FileStorage('${dir.path}/liveclothes_cookies'),
    );
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send(
    () => dio.post<T>(
      path,
      data: body ?? const <String, dynamic>{},
      queryParameters: query,
    ),
  );

  Future<Response<T>> patch<T>(String path, {Object? body}) =>
      _send(() => dio.patch<T>(path, data: body ?? const <String, dynamic>{}));

  Future<Response<T>> delete<T>(String path) =>
      _send(() => dio.delete<T>(path));

  /// Normaliza cualquier fallo de Dio a [AppException] con mensaje para el usuario.
  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _normalize(error);
    }
  }

  static AppException _normalize(DioException error) {
    final response = error.response;
    if (response == null) return AppException.network(error.message);
    final exception = AppException.fromResponse(
      response.statusCode,
      response.data,
    );
    final business = _businessMessage(response.data);
    if (business != null && exception.kind == AppErrorKind.conflict) {
      return AppException(
        exception.kind,
        business,
        code: exception.code,
        statusCode: exception.statusCode,
      );
    }
    return exception;
  }

  static String? _businessMessage(Object? body) {
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message']?.toString();
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }

  /// Limpia la sesión local (usada por el logout, tras avisar al backend).
  Future<void> clearCookies() async {
    try {
      await cookies.deleteAll();
    } catch (_) {
      // Un fallo al limpiar el almacenamiento no debe romper el cierre de sesión.
    }
  }

  void dispose() {
    _unauthorized.close();
  }
}

/// Defensa exigida por el middleware de FastAPI en los métodos que escriben:
/// `Origin` incluido en ALLOWED_ORIGINS + `X-CSRF-Protection: 1`. Los GET no la
/// necesitan (el middleware solo protege métodos que cambian estado).
///
/// Es pública y vive en esta misma librería para poder reutilizarse y probarse.
class BackendSecurityInterceptor extends Interceptor {
  static const Set<String> _safeMethods = {'GET', 'HEAD', 'OPTIONS'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_safeMethods.contains(options.method.toUpperCase())) {
      options.headers['X-CSRF-Protection'] = '1';
      options.headers['Origin'] = Environment.requestOrigin;
    }
    handler.next(options);
  }
}

/// Log mínimo en desarrollo: método, ruta y código de estado.
/// Nunca imprime cookies, contraseñas ni cuerpos con datos sensibles.
class SafeLogInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(
      '${response.requestOptions.method} ${response.requestOptions.path} '
      '-> ${response.statusCode}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode ?? 'sin respuesta';
    _log('${err.requestOptions.method} ${err.requestOptions.path} -> $status');
    handler.next(err);
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[api] $message');
  }
}
