import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Descarcă [text] ca fișier [fileName] (Blob + link temporar). Totul rămâne în browser.
Future<bool> downloadText(String fileName, String text, {String mime = 'application/json'}) async {
  final bytes = utf8.encode(text);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
