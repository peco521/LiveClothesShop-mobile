import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_view.dart';
import '../providers/sesion_provider.dart';

/// Mi cuenta: pantalla compartida de la tienda (accesos a CU15/CU11 y logout).
///
/// No es un caso de uso propio: agrupa acciones de la sesión del cliente con
/// enlaces a los CU que ya existen.
class CuentaScreen extends ConsumerStatefulWidget {
  const CuentaScreen({super.key});

  static const String routePath = '/cuenta';

  @override
  ConsumerState<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends ConsumerState<CuentaScreen> {
  bool _saliendo = false;
  String? _aviso;

  Future<void> _cerrarSesion() async {
    setState(() {
      _saliendo = true;
      _aviso = null;
    });
    try {
      // CU02: avisa al backend, limpia cookies y el estado de sesión; el router
      // redirige al login automáticamente.
      await ref.read(sesionProvider.notifier).cerrarSesion();
      if (mounted) context.go('/login');
    } catch (error) {
      setState(
        () => _aviso = 'No pudimos cerrar la sesión. Inténtalo nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _saliendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider).valueOrNull;
    if (sesion == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi cuenta')),
        body: const EmptyView(
          icon: Icons.lock_outline,
          title: 'Inicia sesión',
          message: 'Necesitas una sesión activa para ver tu cuenta.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gapLarge),
        children: [
          if (_aviso != null) ...[
            NoticeBanner(message: _aviso!),
            const SizedBox(height: AppTheme.gap),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sesion.usuario.nombreMostrado,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sesion.usuario.correo,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rol: ${sesion.rol.descripcion}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.gapLarge),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Mis compras'),
            subtitle: const Text('Historial de compras (CU15)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/historial'),
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Mis reservas'),
            subtitle: const Text('Reservas en sucursal (CU11)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/reservas'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Mi carrito'),
            subtitle: const Text('Productos por comprar (CU12)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/carrito'),
          ),
          const SizedBox(height: AppTheme.gapLarge),
          OutlinedButton(
            onPressed: _saliendo ? null : _cerrarSesion,
            child: Text(_saliendo ? 'Cerrando sesión…' : 'Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
