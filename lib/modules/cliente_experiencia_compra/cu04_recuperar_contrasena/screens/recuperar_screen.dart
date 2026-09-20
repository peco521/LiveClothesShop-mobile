import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../data/recuperacion_repository.dart';

/// CU04 paso 1: solicitar el enlace de recuperación por correo.
class RecuperarScreen extends ConsumerStatefulWidget {
  const RecuperarScreen({super.key});

  static const String routePath = '/recuperar';

  @override
  ConsumerState<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends ConsumerState<RecuperarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  bool _enviando = false;
  String? _aviso;
  bool _exito = false;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await ref.read(recuperacionRepositoryProvider).solicitar(_correo.text);
      setState(() {
        _exito = true;
        _aviso = 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.';
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
      appBar: AppBar(title: const Text('Recuperar contraseña')),
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
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo de tu cuenta',
                  ),
                  validator: (value) {
                    final correo = value?.trim() ?? '';
                    if (correo.isEmpty) return 'Escribe tu correo';
                    if (!correo.contains('@')) return 'El correo no es válido';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.gapLarge),
                ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  child: Text(_enviando ? 'Enviando…' : 'Enviar enlace'),
                ),
                TextButton(
                  onPressed: () => context.go('/restablecer'),
                  child: const Text('Ya tengo el código de recuperación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
