import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../data/recuperacion_repository.dart';

/// CU04 paso 2: restablecer la contraseña con el token recibido por correo.
class RestablecerScreen extends ConsumerStatefulWidget {
  const RestablecerScreen({super.key});

  static const String routePath = '/restablecer';

  @override
  ConsumerState<RestablecerScreen> createState() => _RestablecerScreenState();
}

class _RestablecerScreenState extends ConsumerState<RestablecerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _enviando = false;
  String? _aviso;
  bool _exito = false;

  @override
  void dispose() {
    _token.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await ref
          .read(recuperacionRepositoryProvider)
          .restablecer(token: _token.text, nuevaContrasena: _contrasena.text);
      setState(() {
        _exito = true;
        _aviso = 'Contraseña actualizada. Ya puedes iniciar sesión.';
      });
    } on AppException catch (error) {
      setState(() => _aviso = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_aviso != null) ...[
                  NoticeBanner(message: _aviso!, success: _exito),
                  const SizedBox(height: AppTheme.gap),
                ],
                TextFormField(
                  controller: _token,
                  decoration: const InputDecoration(
                    labelText: 'Código de recuperación',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) == 43
                      ? null
                      : 'El código tiene 43 caracteres',
                ),
                const SizedBox(height: AppTheme.gap),
                TextFormField(
                  controller: _contrasena,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                  ),
                  validator: (value) => (value?.length ?? 0) >= 12
                      ? null
                      : 'La contraseña debe tener al menos 12 caracteres',
                ),
                const SizedBox(height: AppTheme.gap),
                TextFormField(
                  controller: _confirmacion,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Repite la nueva contraseña',
                  ),
                  validator: (value) => value == _contrasena.text
                      ? null
                      : 'Las contraseñas no coinciden',
                ),
                const SizedBox(height: AppTheme.gapLarge),
                if (_exito)
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Ir a iniciar sesión'),
                  )
                else
                  ElevatedButton(
                    onPressed: _enviando ? null : _enviar,
                    child: Text(
                      _enviando ? 'Guardando…' : 'Cambiar contraseña',
                    ),
                  ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Volver al inicio de sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
