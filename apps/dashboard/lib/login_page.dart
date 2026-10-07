import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';

/// Autentificarea adulților (ADR-012). După autentificare, copiii de pe server apar primii.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  /// Contul are 2FA: după parola corectă se cere codul din aplicația de autentificare.
  bool _askCode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(serverChildrenProvider.notifier)
          .signIn(
            _email.text,
            _password.text,
            code: _askCode ? _code.text.trim() : null,
          );
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _askCode |= e.needsTotp;
      });
    } on Object {
      setState(() => _error = 'Serverul nu răspunde. Încearcă mai târziu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Autentificare')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('login-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('login-password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Parolă',
                    errorText: _askCode ? null : _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_askCode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('login-code'),
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Codul din aplicația de autentificare',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('login-submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Se verifică…' : 'Intră'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
