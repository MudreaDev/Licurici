import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';

/// Legătura din e-mailul de confirmare: `#/confirmare?token=…` (ADR-032).
class ConfirmEmailPage extends ConsumerStatefulWidget {
  const ConfirmEmailPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends ConsumerState<ConfirmEmailPage> {
  bool? _ok;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirm();
  }

  Future<void> _confirm() async {
    try {
      await ref.read(apiClientProvider).verifyEmail(widget.token);
      if (mounted) setState(() => _ok = true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _error = e.status == 400
              ? 'Legătura a expirat sau a fost deja folosită. Din „Contul meu” poți cere una nouă.'
              : e.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _ok = false;
          _error = 'Serverul nu răspunde. Încearcă mai târziu.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _EmailScaffold(
    title: 'Confirmarea adresei',
    child: switch (_ok) {
      null => const Center(child: CircularProgressIndicator()),
      true => const Text(
        'Gata, adresa de e-mail e confirmată. Mulțumim!',
        key: ValueKey('confirm-ok'),
      ),
      false => Text(_error!, key: const ValueKey('confirm-error')),
    },
  );
}

/// Legătura din e-mailul „Parolă nouă”: `#/parola-noua?token=…` (ADR-032).
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 10) return setState(() => _error = 'Cel puțin 10 caractere.');
    if (_password.text != _again.text) return setState(() => _error = 'Parolele nu sunt la fel.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).resetPassword(widget.token, _password.text);
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.details.any((d) => d.startsWith('token'))
              ? 'Legătura a expirat sau a fost deja folosită. Cere una nouă de la „Am uitat parola”.'
              : e.message,
        );
      }
    } on Object {
      if (mounted) setState(() => _error = 'Serverul nu răspunde. Încearcă mai târziu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _EmailScaffold(
    title: 'Parolă nouă',
    child: _done
        ? const Text(
            'Parola a fost schimbată. Sesiunile deschise pe alte dispozitive s-au închis; intră din nou cu parola nouă.',
            key: ValueKey('reset-ok'),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('reset-password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Parola nouă', helperText: 'Cel puțin 10 caractere.'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('reset-again'),
                controller: _again,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Încă o dată', errorText: _error),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('reset-submit'),
                onPressed: _busy ? null : _submit,
                child: const Text('Schimbă parola'),
              ),
            ],
          ),
  );
}

class _EmailScaffold extends StatelessWidget {
  const _EmailScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(height: 24),
              TextButton(onPressed: () => context.go('/autentificare'), child: const Text('La autentificare')),
            ],
          ),
        ),
      ),
    ),
  );
}
