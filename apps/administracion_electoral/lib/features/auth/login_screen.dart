import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';

/// Acceso del personal electoral.
///
/// Requiere una cuenta creada por un administrador (Auth por email/contraseña).
/// El rol y el ámbito los resuelve el backend; esta pantalla solo abre sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text,
            password: _password.text,
          );
      final auth = ref.read(authControllerProvider);
      if (auth.hasError) {
        setState(() => _error = _describe(auth.error));
      } else if (auth.value == null) {
        setState(() {
          _error = 'La cuenta no tiene un perfil habilitado en el sistema. '
              'Pide a un administrador que la configure.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _describe(Object? error) {
    if (error is AuthException) return error.message;
    return 'No se pudo iniciar sesión. Revisa tu conexión e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KiteSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: KiteCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.how_to_vote_outlined, size: 48, color: c.primary),
                    const SizedBox(height: KiteSpace.lg),
                    Text(
                      'Administración Electoral',
                      textAlign: TextAlign.center,
                      style: t.h3,
                    ),
                    const SizedBox(height: KiteSpace.xs),
                    Text(
                      'Acceso del personal autorizado.',
                      textAlign: TextAlign.center,
                      style: t.muted,
                    ),
                    const SizedBox(height: KiteSpace.xl),
                    if (_error != null) ...[
                      KiteAlert(
                        title: 'No se pudo acceder',
                        description: _error,
                        tone: KiteTone.danger,
                      ),
                      const SizedBox(height: KiteSpace.lg),
                    ],
                    KiteField(
                      label: 'Correo electrónico',
                      child: KiteInput(
                        controller: _email,
                        placeholder: 'persona@institucion.edu.ec',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    KiteField(
                      label: 'Contraseña',
                      child: KiteInput(
                        controller: _password,
                        placeholder: '••••••••',
                        obscure: true,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    KiteButton(
                      expands: true,
                      enabled: !_submitting,
                      onPressed: _submit,
                      child: Text(_submitting ? 'Ingresando…' : 'Ingresar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
