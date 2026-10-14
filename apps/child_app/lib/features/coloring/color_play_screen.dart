import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/mascot.dart';
import '../../shared/ui/candy.dart';
import '../../shared/voice.dart';
import '../aquarium/coloring_screen.dart';
import 'coloring_pages.dart';
import 'drawings_store.dart';
import '../../app/nav_memory.dart';

/// Colorăm (catalog #58, joc liber): pagini de colorat desenate din cod (casa, floarea,
/// mașina…), cu aceleași unelte ca peștii. La „Gata!” desenul apare într-o ramă, Licurici
/// se bucură, iar desenul se păstrează în „Desenele mele” (doar pe tabletă). E creație, nu
/// sarcină: nu se notează încercări și nu se dau stele.
class ColorPlayScreen extends ConsumerWidget {
  const ColorPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ColoringScreen(
    pages: picturePages,
    pickPrompt: 'Alege un desen.',
    startPrompt: 'Colorează cum vrei tu.',
    showAquarium: false,
    onDone: (context, page, drawing) => _framed(context, ref, page, drawing),
  );

  Future<void> _framed(BuildContext context, WidgetRef ref, ColoringPage page, ui.Image drawing) async {
    final png = (await drawing.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    await ref.read(drawingStoreProvider).add(SavedDrawing('d${DateTime.now().microsecondsSinceEpoch}', page.id, png));
    ref.invalidate(drawingsProvider);
    ref.read(voiceProvider).say(['Ce desen frumos!']);
    if (!context.mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth.clamp(0, 640).toDouble();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rama de lemn.
                Flexible(
                  child: Container(
                    width: w,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(colors: [Color(0xFFD9A066), Color(0xFFA8703C)]),
                      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(aspectRatio: 1000 / 600, child: Image.memory(png, fit: BoxFit.contain)),
                    ),
                  ).animate().scale(begin: const Offset(0.85, 0.85), duration: 350.ms, curve: Curves.easeOutBack),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Mascot(size: 72, mood: MascotMood.celebrate),
                    CandyButton(
                      key: const ValueKey('draw-again'),
                      label: 'Încă un desen',
                      icon: Icons.brush_rounded,
                      color: Tokens.primary,
                      minWidth: 180,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                    CandyButton(
                      key: const ValueKey('draw-home'),
                      label: 'Acasă',
                      icon: Icons.home_rounded,
                      color: Tokens.good,
                      minWidth: 140,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    if (again == false && context.mounted) goBackToMenu(context, ref);
  }
}
