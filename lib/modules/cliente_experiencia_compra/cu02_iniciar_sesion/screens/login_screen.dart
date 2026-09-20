import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../shared/providers/sesion_provider.dart';

/// CU02 Iniciar sesión del cliente (`POST /api/auth/login/cliente`).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String routePath = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  String? _aviso;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _aviso = null);
    await ref
        .read(sesionProvider.notifier)
        .iniciarSesion(correo: _correo.text, contrasena: _contrasena.text);
    if (!mounted) return;
    final estado = ref.read(sesionProvider);
    estado.when(
      data: (sesion) {
        if (sesion == null) {
          setState(() => _aviso = 'Correo o contraseña incorrectos.');
        } else {
          context.go('/catalogo');
        }
      },
      loading: () {},
      error: (error, _) => setState(() => _aviso = mensajeDeError(error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cargando = ref.watch(sesionProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'LiveClothesShop',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ingresa para ver el catálogo de poleras y tus pedidos.',
                  style: TextStyle(color: Color(0xFF64695F)),
                ),
                const SizedBox(height: AppTheme.gapLarge),
                if (_aviso != null) ...[
                  NoticeBanner(message: _aviso!),
                  const SizedBox(height: AppTheme.gap),
                ],
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (value) {
                    final correo = value?.trim() ?? '';
                    if (correo.isEmpty) return 'Escribe tu correo';
                    if (!correo.contains('@')) return 'El correo no es válido';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.gap),
                TextFormField(
                  controller: _contrasena,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Escribe tu contraseña' : null,
                ),
                const SizedBox(height: AppTheme.gapLarge),
                ElevatedButton(
                  onPressed: cargando ? null : _enviar,
                  child: cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ingresar'),
                ),
                const SizedBox(height: AppTheme.gap),
                OutlinedButton(
                  onPressed: cargando ? null : () => context.go('/registro'),
                  child: const Text('Crear cuenta'),
                ),
                TextButton(
                  onPressed: cargando ? null : () => context.go('/recuperar'),
                  child: const Text('Olvidé mi contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
