import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

/// Aplicación móvil de LiveClothesShop (misma identidad visual que la web).
class LiveClothesShopApp extends ConsumerWidget {
  const LiveClothesShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'LiveClothesShop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Accesibilidad: se respeta el escalado de texto sin romper el layout.
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Política de reintentos de Riverpod para toda la app.
///
/// Riverpod 3 reintenta por defecto cada provider fallido con backoff
/// exponencial; mientras reintenta, el estado sigue siendo `AsyncLoading`, así
/// que el usuario vería un indicador de carga eterno en lugar del error. Aquí
/// se desactiva el reintento automático porque cada pantalla ofrece un botón
/// "Reintentar" explícito (CU10, CU11, CU12, CU15 y CU17).
///
/// Se declara como closure de tipo inferido porque flutter_riverpod 3.4 no
/// exporta el typedef `Retry` (solo se acepta como parámetro de `ProviderScope`
/// y de `ProviderContainer`).
// ignore: prefer_function_declarations_over_variables
final sinReintentosAutomaticos = (_, _) => null;
