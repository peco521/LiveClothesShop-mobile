import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';

void main() {
  group('ApiClient.extractCredential', () {
    const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno12'; // 43 caracteres
    test('extrae la credencial de Set-Cookie', () {
      expect(token.length, 43);
      expect(
        ApiClient.extractCredential('liveclothes_session=$token; Path=/api; HttpOnly; SameSite=Lax'),
        token,
      );
    });

    test('retorna null sin cabecera o con formato inválido', () {
      expect(ApiClient.extractCredential(null), isNull);
      expect(ApiClient.extractCredential(''), isNull);
      expect(ApiClient.extractCredential('otro=abc; Path=/'), isNull);
      expect(ApiClient.extractCredential('liveclothes_session=corto; Path=/api'), isNull);
    });

    test('no acepta nombre de cookie distinto', () {
      expect(ApiClient.extractCredential('liveclothes_session=$token; Path=/api', 'otra'), isNull);
    });
  });

  group('ApiException.userMessage', () {
    test('mensajes funcionales sin detalles internos', () {
      expect(const ApiException(401, 'x').userMessage, contains('sesión'));
      expect(const ApiException(403, 'x').userMessage, contains('autorización'));
      expect(const ApiException(404, 'producto_no_encontrado').userMessage, contains('prenda'));
      expect(const ApiException(422, 'x').userMessage, contains('válidos'));
      expect(const ApiException(0, 'error_conexion').userMessage, contains('conexión'));
      expect(const ApiException(500, 'error_interno').userMessage, isNotEmpty);
    });
  });
}
