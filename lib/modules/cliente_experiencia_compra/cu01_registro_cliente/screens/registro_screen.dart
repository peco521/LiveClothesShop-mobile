import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../shared/providers/sesion_provider.dart';
import '../data/registro_repository.dart';

/// CU01 Registro de cliente (`POST /api/auth/registro`).
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  static const String routePath = '/registro';

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ci = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidoPat = TextEditingController();
  final _apellidoMat = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _contrasena = TextEditingController();
  String _sexo = 'F';
  DateTime? _fechaNac;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _ci,
      _nombres,
      _apellidoPat,
      _apellidoMat,
      _correo,
      _telefono,
      _direccion,
      _contrasena,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNac ?? DateTime(hoy.year - 20, hoy.month, hoy.day),
      firstDate: DateTime(1900),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (fecha != null) setState(() => _fechaNac = fecha);
  }

  String get _fechaTexto {
    final fecha = _fechaNac;
    if (fecha == null) return 'Selecciona tu fecha de nacimiento';
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year.toString().padLeft(4, '0')}-$mes-$dia';
  }

  Future<void> _enviar() async {
    final formValido = _formKey.currentState!.validate();
    if (_fechaNac == null)
      setState(() => _error = 'Selecciona tu fecha de nacimiento');
    if (!formValido || _fechaNac == null) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final resultado = await ref.read(registroRepositoryProvider).registrar({
        'ci': _ci.text.trim(),
        'nombres': _nombres.text.trim(),
        'apellidoPat': _apellidoPat.text.trim(),
        'apellidoMat': _apellidoMat.text.trim(),
        'sexo': _sexo,
        'correo': _correo.text.trim(),
        'telefono': _telefono.text.trim(),
        'direccion': _direccion.text.trim(),
        'fechaNac': _fechaTexto,
        'contrasena': _contrasena.text,
      });
      // El backend ya dejó la cookie de sesión activa: CU01 entra directo a la tienda.
      ref.read(sesionProvider.notifier).establecer(resultado.sesion);
      if (!mounted) return;
      context.go('/catalogo');
    } on AppException catch (error) {
      setState(
        () => _error = error.kind == AppErrorKind.invalid
            ? 'Revisa los datos: hay valores no válidos o el correo ya está registrado.'
            : error.message,
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campo(
    TextEditingController controller,
    String label, {
    int maxLength = 100,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gap),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, counterText: ''),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'Completa $label' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  NoticeBanner(message: _error!),
                  const SizedBox(height: AppTheme.gap),
                ],
                _campo(_ci, 'Carnet de identidad'),
                _campo(_nombres, 'Nombres'),
                _campo(_apellidoPat, 'Apellido paterno', maxLength: 50),
                _campo(_apellidoMat, 'Apellido materno', maxLength: 50),
                DropdownButtonFormField<String>(
                  initialValue: _sexo,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'F', child: Text('Femenino')),
                    DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  ],
                  onChanged: (value) => setState(() => _sexo = value ?? 'F'),
                ),
                const SizedBox(height: AppTheme.gap),
                _campo(
                  _correo,
                  'Correo',
                  maxLength: 100,
                  keyboard: TextInputType.emailAddress,
                ),
                _campo(
                  _telefono,
                  'Teléfono',
                  maxLength: 20,
                  keyboard: TextInputType.phone,
                ),
                _campo(_direccion, 'Dirección', maxLength: 150),
                OutlinedButton(
                  onPressed: _enviando ? null : _elegirFecha,
                  child: Text(_fechaTexto),
                ),
                const SizedBox(height: AppTheme.gap),
                TextFormField(
                  controller: _contrasena,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (mínimo 12 caracteres)',
                  ),
                  validator: (value) {
                    final texto = value ?? '';
                    if (texto.trim().isEmpty)
                      return 'La contraseña no puede estar vacía';
                    if (texto.length < 12) {
                      return 'La contraseña debe tener al menos 12 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.gapLarge),
                ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Registrarme'),
                ),
                TextButton(
                  onPressed: _enviando ? null : () => context.go('/login'),
                  child: const Text('Ya tengo cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
