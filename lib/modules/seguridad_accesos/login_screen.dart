import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';

/// Inicio de sesión del cliente. Reutiliza POST /api/auth/login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _empresa = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _ver = false;
  bool _busy = false;
  bool _staff = false;

  @override
  void dispose() {
    _correo.dispose();
    _empresa.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final session = context.read<SessionState>();
    await session.login(_empresa.text, _correo.text, _contrasena.text, staff: _staff);
    if (!mounted) return;
    setState(() => _busy = false);
    if (session.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(session.user?.isCashier == true ? '/caja' : '/tienda');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = context.watch<SessionState>().error;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              children: [
                const Text('Bienvenido a FashionStore',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 SwitchListTile(title: const Text('Acceso de cajero'), value: _staff,
                   onChanged: _busy ? null : (value) => setState(() => _staff = value)),
                TextFormField(
                  controller: _empresa,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(labelText: 'Código de empresa'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el código de empresa' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contrasena,
                  obscureText: !_ver,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _ver = !_ver),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                ),
                const SizedBox(height: 12),
                if (error != null) Text(error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _entrar,
                  child: Text(_busy ? 'Ingresando…' : 'Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
