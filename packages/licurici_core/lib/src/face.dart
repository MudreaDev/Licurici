/// Fețe desenate din cod (EMO, plan §3): oricâte fețe diferite (ten, păr, coafură, ochi,
/// accesorii), cu o emoție și o **intensitate** 0…1. Pentru generalizare (aceeași emoție pe fețe
/// noi, nu doar pe cele 8 desene ale aceluiași copil) și pentru jocurile care măsoară pragul de
/// recunoaștere (intensitatea minimă la care copilul recunoaște emoția).
///
/// O față e identificată printr-un text (`face:bucuros:2314:80`), folosit ca orice alt stimul
/// (`art` în runde, `stimulusId` în încercări). Emoția apare în text, deci filtrul „imagini de
/// evitat” (`avoid.dart`) le poate exclude (ex. `face:suparat` la „Fețe furioase”).
library;

import 'dart:math';

enum FaceEmotion {
  neutru('liniștit'),
  bucuros('bucuros'),
  trist('trist'),
  suparat('supărat'),
  speriat('speriat'),
  surprins('surprins'),
  obosit('obosit');

  const FaceEmotion(this.word);

  /// Cuvântul rostit („Cine e trist?”).
  final String word;
}

/// Forma feței pentru o emoție la intensitatea maximă (neutru = toate zero / implicite).
/// Valorile sunt în unități relative la mărimea feței; desenul le interpolează după intensitate.
class FaceShape {
  const FaceShape({
    this.mouthCurve = 0.1,
    this.mouthOpen = 0,
    this.mouthWidth = 0.5,
    this.browTilt = 0,
    this.browLift = 0,
    this.eyeOpen = 1,
    this.blush = 0,
    this.tear = 0,
  });

  /// −1 = colțurile gurii în jos … +1 = zâmbet larg.
  final double mouthCurve;

  /// 0 = gura închisă … 1 = larg deschisă.
  final double mouthOpen;
  final double mouthWidth;

  /// + = capătul dinspre nas al sprâncenelor urcă (tristețe, frică); − = coboară (furie).
  final double browTilt;

  /// Cât de sus stau sprâncenele.
  final double browLift;

  /// 1 = normal, < 1 = mijiți (zâmbet, furie), > 1 = larg deschiși (frică, uimire).
  final double eyeOpen;
  final double blush;
  final double tear;

  static const neutral = FaceShape();

  static FaceShape of(FaceEmotion e) => switch (e) {
        FaceEmotion.neutru => neutral,
        FaceEmotion.bucuros => const FaceShape(mouthCurve: 1, mouthOpen: 0.35, mouthWidth: 0.62, browLift: 0.05, eyeOpen: 0.8, blush: 1),
        FaceEmotion.trist => const FaceShape(mouthCurve: -0.85, mouthWidth: 0.42, browTilt: 0.9, eyeOpen: 0.8, tear: 1),
        FaceEmotion.suparat => const FaceShape(mouthCurve: -0.7, mouthOpen: 0.12, mouthWidth: 0.5, browTilt: -1, browLift: -0.15, eyeOpen: 0.72),
        FaceEmotion.speriat => const FaceShape(mouthCurve: -0.3, mouthOpen: 0.6, mouthWidth: 0.42, browTilt: 0.65, browLift: 0.3, eyeOpen: 1.35),
        FaceEmotion.surprins => const FaceShape(mouthOpen: 0.85, mouthWidth: 0.26, browTilt: 0.1, browLift: 0.42, eyeOpen: 1.3),
        FaceEmotion.obosit => const FaceShape(mouthCurve: -0.15, mouthOpen: 0.18, mouthWidth: 0.34, browTilt: 0.25, browLift: -0.08, eyeOpen: 0.35),
      };

  /// Forma la [intensity] ∈ [0, 1]: de la neutru spre emoția întreagă.
  static FaceShape at(FaceEmotion e, double intensity) {
    final t = intensity.clamp(0.0, 1.0);
    final a = neutral, b = of(e);
    double l(double x, double y) => x + (y - x) * t;
    return FaceShape(
      mouthCurve: l(a.mouthCurve, b.mouthCurve),
      mouthOpen: l(a.mouthOpen, b.mouthOpen),
      mouthWidth: l(a.mouthWidth, b.mouthWidth),
      browTilt: l(a.browTilt, b.browTilt),
      browLift: l(a.browLift, b.browLift),
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      blush: l(a.blush, b.blush),
      // Lacrima apare doar la o tristețe clară.
      tear: t >= 0.7 ? b.tear : 0,
    );
  }
}

/// Cine e (identitatea): rămâne la fel când se schimbă emoția.
class FaceLook {
  const FaceLook({this.skin = 0, this.hair = 0, this.hairStyle = 0, this.eyes = 0, this.accessory = 0});

  static const skins = 5, hairs = 6, hairStyles = 5, eyeColors = 4, accessories = 4;

  /// Indici în paletele desenului: ten, culoarea părului, coafura (scurt, lung, codițe, creț,
  /// cu căciulă), ochii, accesoriul (nimic, ochelari, bentiță, pistrui).
  final int skin, hair, hairStyle, eyes, accessory;

  String get code => '$skin$hair$hairStyle$eyes$accessory';

  static FaceLook parse(String code) {
    int d(int i, int n) => i < code.length ? (int.tryParse(code[i]) ?? 0) % n : 0;
    return FaceLook(skin: d(0, skins), hair: d(1, hairs), hairStyle: d(2, hairStyles), eyes: d(3, eyeColors), accessory: d(4, accessories));
  }

  static FaceLook random(Random r) => FaceLook(
        skin: r.nextInt(skins),
        hair: r.nextInt(hairs),
        hairStyle: r.nextInt(hairStyles),
        eyes: r.nextInt(eyeColors),
        accessory: r.nextInt(accessories),
      );

  /// Câte trăsături diferă (pentru „Cine e prietenul?”: distractori mai asemănători = mai greu).
  int differences(FaceLook o) =>
      [skin != o.skin, hair != o.hair, hairStyle != o.hairStyle, eyes != o.eyes, accessory != o.accessory].where((x) => x).length;

  @override
  bool operator ==(Object other) => other is FaceLook && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// O față: cine e, ce simte și cât de tare.
class FaceSpec {
  const FaceSpec(this.look, this.emotion, [this.intensity = 1]);

  final FaceLook look;
  final FaceEmotion emotion;
  final double intensity;

  static const prefix = 'face:';

  /// Identificatorul folosit ca stimul: `face:<emoție>:<cod>:<intensitate în procente>`.
  String get art => '$prefix${emotion.name}:${look.code}:${(intensity * 100).round()}';

  static bool isFace(String art) => art.startsWith(prefix);

  static FaceSpec? parse(String art) {
    if (!isFace(art)) return null;
    final p = art.substring(prefix.length).split(':');
    if (p.length != 3) return null;
    final emotion = FaceEmotion.values.asNameMap()[p[0]];
    final pct = int.tryParse(p[2]);
    if (emotion == null || pct == null) return null;
    return FaceSpec(FaceLook.parse(p[1]), emotion, (pct / 100).clamp(0.0, 1.0));
  }

  FaceShape get shape => FaceShape.at(emotion, intensity);
}

/// [count] fețe diferite (identități distincte), toate cu [emotion], intensitate între
/// [minIntensity] și 1. Determinist după [random].
List<FaceSpec> distinctFaces(Random random, FaceEmotion emotion, int count, {double minIntensity = 0.75}) {
  final looks = <FaceLook>{};
  var guard = 0;
  while (looks.length < count && guard++ < 1000) {
    looks.add(FaceLook.random(random));
  }
  return [
    for (final l in looks) FaceSpec(l, emotion, minIntensity + (1 - minIntensity) * random.nextDouble()),
  ];
}
