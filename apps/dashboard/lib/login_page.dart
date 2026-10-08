import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';

enum _Mode { login, register, forgot }

/// Autentificarea adulților (ADR-012), contul nou și „Am uitat parola” (ADR-032).
/// După autentificare, copiii de pe server apar primii.
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
  String? _info;
  bool _busy = false;
  _Mode _mode = _Mode.login;
  String _role = 'PARENT';
  bool _accepted = false;

  /// Contul are 2FA: după parola corectă se cere codul din aplicația de autentificare.
  bool _askCode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _switch(_Mode mode) => setState(() {
    _mode = mode;
    _error = null;
    _info = null;
    _askCode = false;
  });

  Future<void> _submit() async {
    if (_mode == _Mode.register && _password.text.length < 10) {
      setState(() => _error = 'Parola trebuie să aibă cel puțin 10 caractere.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final children = ref.read(serverChildrenProvider.notifier);
    try {
      switch (_mode) {
        case _Mode.login:
          await children.signIn(_email.text, _password.text, code: _askCode ? _code.text.trim() : null);
          if (mounted) context.go('/');
        case _Mode.register:
          await children.register(_email.text, _password.text, role: _role);
          if (mounted) context.go('/cont');
        case _Mode.forgot:
          await ref.read(apiClientProvider).forgotPassword(_email.text);
          setState(
            () => _info =
                'Dacă adresa are cont, în câteva minute primești un e-mail cu legătura pentru parola nouă '
                '(valabilă o oră). Verifică și dosarul Spam.',
          );
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.status == 400 && e.details.any((d) => d.startsWith('email'))
            ? 'Adresa de e-mail nu pare corectă.'
            : e.message;
        _askCode |= e.needsTotp;
      });
    } on Object {
      setState(() => _error = 'Serverul nu răspunde. Încearcă mai târziu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.login => 'Autentificare',
      _Mode.register => 'Cont nou',
      _Mode.forgot => 'Am uitat parola',
    };
    final submit = switch (_mode) {
      _Mode.login => 'Intră',
      _Mode.register => 'Creează contul',
      _Mode.forgot => 'Trimite legătura',
    };
    final canSubmit = !_busy && (_mode != _Mode.register || _accepted);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_mode == _Mode.register) ...[
                      SegmentedButton<String>(
                        key: const ValueKey('register-role'),
                        segments: const [
                          ButtonSegment(value: 'PARENT', label: Text('Sunt părinte'), icon: Icon(Icons.family_restroom)),
                          ButtonSegment(value: 'THERAPIST', label: Text('Sunt specialist'), icon: Icon(Icons.medical_services_outlined)),
                        ],
                        selected: {_role},
                        onSelectionChanged: (s) => setState(() => _role = s.first),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      key: const ValueKey('login-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        errorText: _mode == _Mode.forgot ? _error : null,
                      ),
                      onSubmitted: _mode == _Mode.forgot ? (_) => _submit() : null,
                    ),
                    if (_mode != _Mode.forgot) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('login-password'),
                        controller: _password,
                        obscureText: true,
                        autofillHints: [_mode == _Mode.register ? AutofillHints.newPassword : AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Parolă',
                          helperText: _mode == _Mode.register ? 'Cel puțin 10 caractere.' : null,
                          errorText: _askCode ? null : _error,
                        ),
                        onSubmitted: (_) => canSubmit ? _submit() : null,
                      ),
                    ],
                    if (_askCode) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('login-code'),
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        decoration: InputDecoration(labelText: 'Codul din aplicația de autentificare', errorText: _error),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_mode == _Mode.register)
                      CheckboxListTile(
                        key: const ValueKey('register-accept'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _accepted,
                        onChanged: (v) => setState(() => _accepted = v ?? false),
                        title: const Text(
                          'Am citit termenii și politica de confidențialitate. Datele copilului se trimit pe server '
                          'doar după ce îmi dau acordul separat, din tabletă sau din „Contul meu”.',
                        ),
                      ),
                    if (_info != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_info!, key: const ValueKey('login-info')),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('login-submit'),
                      onPressed: canSubmit ? _submit : null,
                      child: Text(_busy ? 'Se verifică…' : submit),
                    ),
                    const SizedBox(height: 8),
                    if (_mode == _Mode.login) ...[
                      TextButton(
                        key: const ValueKey('to-forgot'),
                        onPressed: () => _switch(_Mode.forgot),
                        child: const Text('Am uitat parola'),
                      ),
                      TextButton(
                        key: const ValueKey('to-register'),
                        onPressed: () => _switch(_Mode.register),
                        child: const Text('Nu am cont — îmi fac unul'),
                      ),
                    ] else
                      TextButton(
                        key: const ValueKey('to-login'),
                        onPressed: () => _switch(_Mode.login),
                        child: const Text('Am cont — intru'),
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
