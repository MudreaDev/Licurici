/// Modelul de dezvoltare (plan §3, ADR-026): arii → trepte → încercări.
/// Treptele de aici sunt prima versiune (de validat cu un specialist, plan §10); vor fi mutate
/// în JSON (`game_content/trasee/<arie>.json`) când le editează panoul.
library;

/// Ariile de dezvoltare (plan §3.1).
enum Domain {
  atn('ATN', 'Atenție și atenție comună'),
  imi('IMI', 'Imitație'),
  pot('POT', 'Potrivire și percepție vizuală'),
  lrc('LRC', 'Limbaj receptiv'),
  com('COM', 'Comunicare și limbaj expresiv'),
  cog('COG', 'Cogniție'),
  emo('EMO', 'Emoții și cogniție socială'),
  fex('FEX', 'Funcții executive și autoreglare'),
  aut('AUT', 'Autonomie și rutine'),
  mot('MOT', 'Motricitate fină'),
  pac('PAC', 'Pre-academic → academic');

  const Domain(this.code, this.label);

  final String code;
  final String label;

  static Domain fromCode(String code) => Domain.values.firstWhere(
        (d) => d.code == code,
        orElse: () => throw ArgumentError.value(code, 'code', 'arie necunoscută'),
      );
}

/// O treaptă dintr-un traseu: un obiectiv observabil, cu jocurile care îl exersează.
class Step {
  const Step(this.id, this.objective, {this.games = const []});

  /// `EMO3`, `PAC-N4`.
  final String id;
  final String objective;

  /// Id-urile jocurilor care exersează treapta.
  final List<String> games;

  Domain get domain => Domain.fromCode(id.split(RegExp('[-0-9]')).first);

  @override
  String toString() => 'Step($id)';
}

/// Traseul unei arii: trepte ordonate de la mic la mare.
class Ladder {
  const Ladder(this.domain, this.steps);

  final Domain domain;
  final List<Step> steps;

  Step? step(String id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Treapta următoare (null la capăt).
  Step? after(String id) {
    final i = steps.indexWhere((s) => s.id == id);
    return i < 0 || i + 1 >= steps.length ? null : steps[i + 1];
  }
}

/// Traseele de pornire (plan §3.2 + catalog). Doar ariile cu jocuri în aplicație.
const List<Ladder> ladders = [
  Ladder(Domain.atn, [
    Step('ATN1', 'Se orientează spre un stimul care apare în centru', games: ['prinde-licuriciul']),
    Step('ATN2', 'Găsește stimulul oriunde pe ecran, inclusiv la margini',
        games: ['prinde-licuriciul', 'cauta']),
    Step('ATN2b', 'Urmărește cu privirea un obiect care se mișcă, chiar printre altele asemănătoare',
        games: ['urmareste-pestele']),
    Step('ATN3', 'Urmărește privirea și gestul cuiva spre un obiect', games: ['unde-se-uita']),
    Step('ATN4', 'Urmărește doar privirea (fără gest)', games: ['unde-se-uita']),
    Step('ATN5', 'Observă ce s-a schimbat într-o scenă (a apărut, s-a înlocuit, a dispărut)',
        games: ['ce-s-a-schimbat']),
  ]),
  Ladder(Domain.imi, [
    Step('IMI1', 'Imită o acțiune simplă pe ecran (atinge ce a atins Licurici)',
        games: ['fa-ca-licuriciul']),
    Step('IMI2', 'Imită două acțiuni în ordine', games: ['fa-ca-licuriciul']),
    Step('IMI3', 'Imită trei acțiuni, inclusiv tragerea unui obiect', games: ['fa-ca-licuriciul']),
    Step('IMI4', 'Repetă un ritm bătut la tobă', games: ['toba-magica']),
    Step('IMI5', 'Copiază un model din piese (construiește la fel)', games: ['construieste']),
  ]),
  Ladder(Domain.pot, [
    Step('POT1', 'Potrivește un obiect identic, din două variante', games: ['potriveste']),
    Step('POT2', 'Potrivește un obiect identic, din 3–5 variante', games: ['potriveste']),
    Step('POT3', 'Potrivește obiectul cu umbra lui (siluetă)', games: ['umbre']),
    Step('POT5', 'Potrivește culori și forme pe obiecte diferite', games: ['culori', 'forme']),
    Step('POT6', 'Găsește ce nu se potrivește într-o categorie', games: ['intrusul']),
    Step('POT7', 'Reface o imagine din piese (puzzle 2 → 9 piese)', games: ['puzzle']),
    Step('POT8', 'Găsește diferențele dintre două scene', games: ['diferente']),
    Step('POT9', 'Găsește o formă ascunsă într-un desen încâlcit (figuri încastrate)',
        games: ['forma-ascunsa']),
  ]),
  Ladder(Domain.lrc, [
    Step('LRC1', 'Arată obiectul numit, din două variante (obiecte foarte cunoscute)',
        games: ['arata-mi']),
    Step('LRC2', 'Arată obiectul numit, din 3–5 variante, peste 20 de obiecte', games: ['arata-mi']),
    Step('LRC3', 'Arată părțile corpului', games: ['corpul']),
    Step('LRC3b', 'Înțelege acțiuni: „cine doarme?”, „cine mănâncă?”', games: ['ce-face']),
    Step('LRC4', 'Înțelege un atribut: mare / mic, culoare („cartea verde”)',
        games: ['mingea-rosie']),
    Step('LRC5', 'Urmează o instrucțiune în 2–3 pași („atinge mărul, apoi mingea”)', games: ['asculta-si-fa']),
    Step('LRC6', 'Înțelege pozițiile: pe, sub, în, lângă, deasupra', games: ['unde-e-ursul']),
    Step('LRC6b', 'Înțelege sus, jos, stânga, dreapta (și colțurile)', games: ['pozitii']),
    Step('LRC7', 'Răspunde la întrebări despre o poveste ascultată', games: ['povesti']),
  ]),
  Ladder(Domain.com, [
    Step('COM1', 'Asociază un sunet cu cine îl face (animale, lucruri)', games: ['ce-se-aude']),
    Step('COM2', 'Răspunde cu da/nu la întrebări despre ce vede', games: ['da-nu']),
    Step('COM3', 'Cere ce vrea cu pictograme („Vreau apă”)', games: ['vorbeste']),
    Step('COM4', 'Recunoaște primul sunet al unui cuvânt', games: ['primul-sunet', 'ce-ai-auzit']),
    Step('COM5', 'Alcătuiește o propoziție din pictograme (cine — ce face — cu ce)',
        games: ['spune-propozitia']),
  ]),
  Ladder(Domain.cog, [
    Step('COG1', 'Înțelege cauză–efect: atinge intenționat ca să se întâmple ceva',
        games: ['atinge-si-vezi']),
    Step('COG2', 'Găsește un obiect ascuns, chiar dacă s-a mutat (permanența obiectului)',
        games: ['cucu-bau']),
    Step('COG3', 'Sortează obiecte după categorie', games: ['sortam', 'la-locul-lui']),
    Step('COG4', 'Ordonează după mărime (de la mic la mare)', games: ['mare-mic']),
    Step('COG5', 'Continuă un model (AB, AAB, ABC)', games: ['continua-sirul']),
    Step('COG7', 'Cunoaște anotimpurile și semnele lor', games: ['anotimpuri']),
    Step('COG8', 'Știe unde trăiesc animalele', games: ['habitate']),
    Step('COG6', 'Pune în ordine imaginile unei întâmplări', games: ['ce-urmeaza']),
    Step('COG9', 'Aplică ce știe despre natură: case, anotimpuri, hrană, reciclare', games: ['explorare-stiinte']),
  ]),
  Ladder(Domain.emo, [
    Step('EMO1', 'Deosebește bucuros de trist', games: ['emotii']),
    Step('EMO2', 'Recunoaște emoțiile de bază pe fețe diferite',
        games: ['emotii', 'sortam-emotiile', 'cat-de-tare', 'cine-e-prietenul']),
    Step('EMO3', 'Spune ce simte cineva într-o situație', games: ['ce-simte', 'cum-se-simte']),
    Step('EMO4', 'Alege ce poate face cineva ca să se simtă mai bine', games: ['ce-ma-ajuta']),
    Step('EMO5', 'Înțelege ce știe și ce crede altcineva (perspectivă)', games: ['cine-stie']),
    Step('EMO6', 'Alege comportamentul potrivit în situații sociale', games: ['situatii']),
    Step('EMO7', 'Își așteaptă rândul într-un joc cu altcineva și dă rândul mai departe',
        games: ['pe-rand']),
  ]),
  Ladder(Domain.fex, [
    Step('FEX1', 'Așteaptă semnalul (verde) înainte să atingă', games: ['semaforul', 'floarea-creste']),
    Step('FEX2', 'Atinge doar ținta cerută și se abține la celelalte (go/no-go)',
        games: ['pescarul']),
    Step('FEX2b', 'Ignoră vecinii care distrag și răspunde doar la țintă (Flanker)',
        games: ['peste-in-mijloc']),
    Step('FEX3', 'Sortează după o regulă (culoare)', games: ['regula-se-schimba']),
    Step('FEX4', 'Schimbă regula când i se cere (acum după formă) — flexibilitate',
        games: ['regula-se-schimba']),
    Step('FEX5', 'Ține minte și repetă o secvență (memorie de lucru)', games: ['simon', 'perechi']),
    Step('FEX5b', 'Ține minte locurile, în ordinea în care s-au aprins (memorie vizuo-spațială)',
        games: ['licuricii']),
    Step('FEX7', 'Planifică un drum printr-un labirint', games: ['labirint']),
    Step('FEX6', 'Se liniștește cu respirația ghidată', games: ['respira']),
  ]),
  Ladder(Domain.aut, [
    Step('AUT1', 'Pune în ordine pașii unei rutine: întâi … apoi … (2–3 pași)',
        games: ['pasii-rutinei', 'ajuta-l-pe-licurici']),
    Step('AUT2', 'Pune în ordine o rutină întreagă (4–5 pași)', games: ['pasii-rutinei', 'ajuta-l-pe-licurici']),
    Step('AUT3', 'Alege hainele potrivite vremii', games: ['ce-imbrac']),
    Step('AUT4', 'Pune în ordine momentele zilei (orarul vizual)', games: ['orarul-meu']),
    Step('AUT5', 'Cumpără după o listă cu poze', games: ['la-magazin']),
    Step('AUT6', 'Alege ce e sănătos și ce e sigur; potrivește emoțiile', games: ['explorare-viata']),
  ]),
  Ladder(Domain.mot, [
    Step('MOT0', 'Atinge repede și precis ținte tot mai mici, tot mai depărtate', games: ['atinge-rapid']),
    Step('MOT1', 'Duce degetul pe un drum lat, drept, de la start la țintă', games: ['traseaza', 'uneste-punctele']),
    Step('MOT2', 'Urmărește curbe și valuri fără să iasă de pe drum', games: ['traseaza', 'uneste-punctele']),
    Step('MOT3', 'Urmărește zig-zag și bucle pe un drum îngust, fără ajutor', games: ['traseaza', 'uneste-punctele']),
    Step('MOT4', 'Trage un obiect precis la o țintă care se mișcă', games: ['hraneste-pestii']),
    Step('MOT5', 'Colorează în contur, cu carioca și cu găleata (motricitate fină, creație)',
        games: ['colorare']),
  ]),
  Ladder(Domain.pac, [
    Step('PAC-N1', 'Vede dintr-o privire câte sunt, fără să numere (subitizare 1–4)', games: ['cate-sunt']),
    Step('PAC-N2', 'Numără până la 5', games: ['numaram']),
    Step('PAC-N3', 'Scrie cifrele urmărind conturul, în ordinea corectă a trăsăturilor',
        games: ['scriem-cifrele']),
    Step('PAC-N4', 'Compară cantități (mai mult / mai puțin)', games: ['comparam']),
    Step('PAC-N5', 'Așază numerele pe o linie de la 0 la 10, 20, apoi 100 (estimare)', games: ['linia-numerelor']),
    Step('PAC-N6', 'Adună cu obiecte', games: ['adunam']),
    Step('PAC-N7', 'Scade cu obiecte', games: ['scadem']),
    Step('PAC-N8', 'Compară numere cu semnele < > =', games: ['semne']),
    Step('PAC-N9', 'Găsește numărul care lipsește dintr-o adunare', games: ['numarul-lipsa']),
    Step('PAC-N10', 'Zeci și unități (valoarea poziției)', games: ['zeci']),
    Step('PAC-N11', 'Înmulțirea ca grupe egale', games: ['inmultim']),
    Step('PAC-N12', 'Împărțirea în grupe egale', games: ['impartim']),
    Step('PAC-N13', 'Tabla înmulțirii până la 10 × 10', games: ['tabla']),
    Step('PAC-N14', 'Rezolvă probleme cu text (adunare, scădere, înmulțire)', games: ['probleme']),
    Step('PAC-T0', 'Știe zilele săptămânii și lunile anului, în ordine; ieri, azi, mâine',
        games: ['calendar']),
    Step('PAC-T1', 'Citește ceasul (ore, jumătăți, sferturi)', games: ['ceasul']),
    Step('PAC-T2', 'Numără banii (lei)', games: ['bani']),
    Step('PAC-L1', 'Recunoaște literele', games: ['alfabetul']),
    Step('PAC-L4', 'Scrie literele de tipar urmărind conturul, în ordinea corectă a trăsăturilor',
        games: ['scriem-literele']),
    Step('PAC-L2', 'Desparte cuvintele în silabe', games: ['silabe']),
    Step('PAC-L3', 'Citește cuvinte simple', games: ['cuvinte']),
    Step('PAC-L6', 'Singular și plural', games: ['plural']),
    Step('PAC-L5', 'Vocabular: opuse', games: ['opuse']),
    Step('PAC-L8', 'Scrie corect ortogramele', games: ['ortografie']),
    Step('PAC-L9', 'Recunoaște substantivul, verbul și adjectivul', games: ['gramatica']),
    Step('PAC-I1', 'Deosebește lucrurile de demult de cele de acum', games: ['trecut']),
    Step('PAC-I2', 'Recunoaște simbolurile țării (drapel, stemă, imn)', games: ['simboluri']),
    Step('PAC-I3', 'Știe oameni importanți din istorie și literatură', games: ['personalitati']),
    Step('PAC-I4', 'Explorează cum se trăia demult', games: ['explorare-istorie']),
    Step('PAC-E1', 'Primele cuvinte în engleză (culori, animale, lucruri)', games: ['engleza']),
  ]),
];

Ladder ladderFor(Domain d) => ladders.firstWhere((l) => l.domain == d);

/// Treapta după id, căutată în toate traseele.
Step? stepById(String id) {
  for (final l in ladders) {
    final s = l.step(id);
    if (s != null) return s;
  }
  return null;
}

/// Treapta dinaintea lui [id] în traseul ei (null pentru prima treaptă sau un id necunoscut).
Step? previousStep(String id) {
  for (final l in ladders) {
    final i = l.steps.indexWhere((s) => s.id == id);
    if (i > 0) return l.steps[i - 1];
    if (i == 0) return null;
  }
  return null;
}

/// Treptele exersate de un joc.
List<Step> stepsForGame(String gameId) =>
    [for (final l in ladders) ...l.steps.where((s) => s.games.contains(gameId))];
