/// Descărcarea unui fișier generat în panou (exportul datelor, GDPR art. 20). Pe web creează
/// fișierul în browser; altundeva (și în teste) întoarce `false`, iar apelantul folosește clipboardul.
library;

export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
