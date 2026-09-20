import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador de Dio para pruebas: responde con datos locales, sin red real.
///
/// Registra cada petición y las cabeceras enviadas para poder comprobar cookies
/// y la defensa CSRF que exige FastAPI.
class AdaptadorFalso implements HttpClientAdapter {
  AdaptadorFalso(this.respuestas);

  /// Clave: `"MÉTODO /ruta"`. Valor: `{'status': int, 'data': Object?, 'setCookie': String?}`.
  final Map<String, Map<String, Object?>> respuestas;
  final List<RequestOptions> peticiones = [];

  RequestOptions? ultima(String metodo, String ruta) {
    for (final peticion in peticiones.reversed) {
      if (peticion.method.toUpperCase() == metodo.toUpperCase() &&
          peticion.path == ruta) {
        return peticion;
      }
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    peticiones.add(options);
    final respuesta =
        respuestas['${options.method.toUpperCase()} ${options.path}'];
    final status = (respuesta?['status'] as int?) ?? 200;
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    final cookie = respuesta?['setCookie'] as String?;
    if (cookie != null) headers['set-cookie'] = [cookie];
    if (status == 204 || respuesta == null && status == 204) {
      return ResponseBody.fromString('', status, headers: headers);
    }
    final cuerpo = jsonEncode(respuesta?['data'] ?? <String, Object?>{});
    return ResponseBody.fromString(cuerpo, status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

/// Credencial de sesión con el formato real del backend (43 caracteres).
const credencialSesion = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';

/// Respuesta de `/api/auth/me` y `/api/auth/login/cliente`.
Map<String, Object?> sesionJson({String idUsuario = 'cliente-1'}) => {
  'usuario': {
    'idUsuario': idUsuario,
    'tipo': 'C',
    'nombres': 'Ana Pérez',
    'correo': 'ana@example.com',
  },
  'rol': {'nro': 'cliente', 'descripcion': 'Cliente'},
  'permisos': <String>[],
  'expiraEn': '2030-01-01T00:00:00Z',
};

/// Error de negocio del backend.
Map<String, Object?> errorJson(String code, String message) => {
  'error': {'code': code, 'message': message},
};

/// Cabecera `Set-Cookie` como la emite FastAPI para la sesión.
String cookieSesion({String path = '/api'}) =>
    'liveclothes_session=$credencialSesion; HttpOnly; Path=$path; Max-Age=28800';
