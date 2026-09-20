import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apertura de Stripe Checkout (CU14) en el navegador seguro del sistema.
///
/// La app nunca pide ni guarda datos de tarjeta: Stripe Checkout los gestiona.
/// Al volver, CU14 consulta el estado real en el backend.
class CheckoutLauncher {
  const CheckoutLauncher();

  Future<bool> abrir(String? checkoutUrl) async {
    final url = checkoutUrl?.trim() ?? '';
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Inyectable para poder probar CU14 sin abrir el navegador real.
final checkoutLauncherProvider = Provider<CheckoutLauncher>(
  (ref) => const CheckoutLauncher(),
);
