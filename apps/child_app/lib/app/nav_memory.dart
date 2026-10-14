import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ce ține minte aplicația despre meniuri cât e deschisă (nu se salvează): din ce listă
/// de jocuri a pornit copilul și cât era derulată fiecare listă. Ieșirea din joc îl
/// întoarce exact acolo, nu la începutul listei (previzibil, fără căutat din nou).
class NavMemory {
  String _menu = '/';
  final _offsets = <String, double>{};

  /// Meniul din care s-a deschis ultimul joc (`/` sau `/arie/<cod>`).
  String get menu => _menu;

  /// Un meniu s-a deschis: jocurile pornite de aici se întorc aici.
  void enterMenu(String route) => _menu = route;

  double offset(String route) => _offsets[route] ?? 0;

  void saveOffset(String route, double value) => _offsets[route] = value;

  /// Controlerul de derulare al listei [route], pornit de unde a rămas; poziția se
  /// păstrează la fiecare derulare.
  ScrollController controllerFor(String route) {
    final c = ScrollController(initialScrollOffset: offset(route));
    c.addListener(() {
      if (c.hasClients) saveOffset(route, c.offset);
    });
    return c;
  }
}

final navMemoryProvider = Provider<NavMemory>((ref) => NavMemory());

/// Ieșirea dintr-un joc: înapoi în lista din care a pornit.
void goBackToMenu(BuildContext context, WidgetRef ref) => context.go(ref.read(navMemoryProvider).menu);

/// Locurile care nu sunt jocuri: ecranul principal, ariile, albumul, acvariul, harta,
/// colțul părintelui. Orice altă rută e un joc.
bool isGameRoute(String path) =>
    !(path == '/' ||
        path.startsWith('/arie/') ||
        path.startsWith('/acvariu') ||
        path == '/album' ||
        path == '/harta' ||
        path == '/parinte');
