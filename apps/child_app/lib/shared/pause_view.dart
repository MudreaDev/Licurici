import 'package:flutter/material.dart';

import '../app/layout.dart';
import '../app/theme.dart';
import 'mascot.dart';
import 'ui/candy.dart';

/// Ecranul de pauză al jocurilor cu timp: Licurici așteaptă liniștit, un singur buton mare.
class PauseView extends StatelessWidget {
  const PauseView({super.key, required this.onResume, this.label = 'Continuă'});

  final VoidCallback onResume;
  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return Center(
      child: SingleChildScrollView(
        child: CandyPanel(
          padding: EdgeInsets.fromLTRB(32, compact ? 12 : 22, 32, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(size: compact ? 90 : 150, mood: MascotMood.sleep),
              const SizedBox(height: 6),
              Text(
                'Pauză',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: const Color(0xFF3D5A80),
                ),
              ),
              const SizedBox(height: 14),
              CandyButton(
                label: label,
                icon: Icons.play_arrow_rounded,
                color: Tokens.good,
                onTap: onResume,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
