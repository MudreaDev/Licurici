import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/shared/stimulus_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ilustrațiile refăcute sunt încărcabile și nu sunt tăiate la margine', () async {
    await IllustrationIndex.load();
    const names = [
      'paws', 'trash', 'alarm_clock', 'eagle', 'squid', 'lion', 'lobster',
      'boy', 'dad', 'mom', 'grandma', 'grandpa', 'raise_hand', 'hug',
      'bus', 'cart', 'tap', 'jellyfish', 'deer', 'snowman', 'fries', 'chair',
      'sunglasses', 'lock_open', 'shield', 'parrot', 'girl', 'train', 'palm', 'park', 'wave',
      'handshake', 'school', 'lettuce', 'boot', 'swimming', 'coat',
    ];
    for (final name in names) {
      expect(IllustrationIndex.has('objects/$name'), isTrue, reason: name);
      final data = await rootBundle.load('packages/game_content/art/illustrations/objects/$name.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      int alpha(int x, int y) => bytes[(y * image.width + x) * 4 + 3];
      for (var x = 0; x < image.width; x++) {
        expect(alpha(x, 0), lessThan(80), reason: '$name, sus');
        expect(alpha(x, image.height - 1), lessThan(80), reason: '$name, jos');
      }
      for (var y = 0; y < image.height; y++) {
        expect(alpha(0, y), lessThan(80), reason: '$name, stânga');
        expect(alpha(image.width - 1, y), lessThan(80), reason: '$name, dreapta');
      }
      image.dispose();
      codec.dispose();
    }
  });
}
