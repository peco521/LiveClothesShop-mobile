import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Instancia HTTP única para todos los casos de uso (CU01-CU17).
///
/// `main()` la sobreescribe con la instancia real creada por [ApiClient.create]
/// (Dio + cookie_jar persistentes). En pruebas se sobreescribe con un cliente
/// construido sobre un `CookieJar()` en memoria y un adaptador falso de Dio,
/// para no depender del backend real.
final apiClientProvider = Provider<ApiClient>(
  (ref) => throw UnimplementedError(
    'apiClientProvider debe sobreescribirse en ProviderScope (main o tests)',
  ),
);
