import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/network/providers.dart';

/// Punto de entrada: crea el cliente HTTP único (Dio + cookie_jar persistentes)
/// y lo publica a toda la app mediante Riverpod.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  runApp(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      child: const LiveClothesShopApp(),
    ),
  );
}
