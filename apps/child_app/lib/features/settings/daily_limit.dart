import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'settings.dart';
import '../parent/parent_gate.dart';
import '../../shared/voice.dart';
import '../../data/session.dart';

/// Numără timpul cât aplicația copilului este în prim-plan, fără colțul părintelui.
class DailyLimit extends ConsumerStatefulWidget {
  const DailyLimit({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<DailyLimit> createState() => _DailyLimitState();
}

class _DailyLimitState extends ConsumerState<DailyLimit> with WidgetsBindingObserver {
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  bool _foreground = true;
  bool _redirecting = false;

  String get _day {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get _adult => const ['/parinte', '/bun-venit', '/legare', '/timp-expirat'].contains(widget.router.routerDelegate.currentConfiguration.uri.path);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_routeChanged);
    _clock.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final elapsed = _clock.elapsedMilliseconds;
    _clock.reset();
    final settings = ref.read(settingsProvider);
    if (_foreground && !_adult && settings.dailyMinutes != null) {
      ref.read(settingsProvider.notifier).addUsage(_day, elapsed);
    }
    if (mounted) setState(() {});
  }

  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _tick();
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.router.routerDelegate.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final expired = settings.dailyMinutes != null && settings.usageDay == _day &&
        settings.usageMs >= settings.dailyMinutes! * 60000;
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    final destination = expired && !_adult ? '/timp-expirat' : (!expired && path == '/timp-expirat' ? '/' : null);
    if (destination != null && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (destination == '/timp-expirat') {
            unawaited(ref.read(sessionProvider.notifier).checkpoint(countCompletion: false));
          }
          widget.router.go(destination);
        }
        _redirecting = false;
      });
    }
    return widget.child;
  }
}

class DailyLimitScreen extends ConsumerStatefulWidget {
  const DailyLimitScreen({super.key});

  @override
  ConsumerState<DailyLimitScreen> createState() => _DailyLimitScreenState();
}

class _DailyLimitScreenState extends ConsumerState<DailyLimitScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(['Gata pe azi! Ne jucăm din nou mâine.']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Gata pe azi! Ne jucăm din nou mâine.', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(160, 64)), onPressed: () async {
          if (await askParentGate(context) && context.mounted) context.go('/parinte');
        }, child: const Text('Pentru părinți')),
      ])),
    );
  }
}
