import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'fish_art.dart';

/// Fișa A4 de colorat (ADR-030): marcajele din colțuri, codul modelului, numele și conturul
/// peștelui. Geometria vine din `PaperSheet` (aceeași pe care o caută scanarea).

const _lineInk = Color(0xFF3A3A3A);

/// Titlul fișei: „Peștele-clovn”.
String sheetTitle(FishSpecies s) => s.name[0].toUpperCase() + s.name.substring(1);

/// Fișa pe un `Canvas` Flutter, în milimetri (previzualizare și teste).
void paintPaperSheet(Canvas c, FishSpecies s) {
  c.drawRect(const Rect.fromLTWH(0, 0, PaperSheet.width, PaperSheet.height), Paint()..color = const Color(0xFFFFFFFF));
  final black = Paint()..color = const Color(0xFF000000);
  final white = Paint()..color = const Color(0xFFFFFFFF);
  for (final m in PaperSheet.corners) {
    const size = PaperSheet.marker, u = size / 7;
    c
      ..drawRect(Rect.fromCenter(center: Offset(m.x, m.y), width: size, height: size), black)
      ..drawRect(Rect.fromCenter(center: Offset(m.x, m.y), width: size - 2 * u, height: size - 2 * u), white)
      ..drawRect(Rect.fromCenter(center: Offset(m.x, m.y), width: 3 * u, height: 3 * u), black);
  }
  for (final (x, y, size, dark) in PaperSheet.codeCells(s)) {
    if (dark) c.drawRect(Rect.fromLTWH(x, y, size, size), black);
  }
  c
    ..save()
    ..translate(PaperSheet.boxLeft, PaperSheet.boxTop)
    ..scale(PaperSheet.boxScale);
  paintLineArt(c, s, color: _lineInk);
  c.restore();
  final title = TextPainter(
    text: TextSpan(
      text: sheetTitle(s),
      style: const TextStyle(fontFamily: fontFamily, package: contentPackage, fontSize: 9, color: Color(0xFF222222), fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  title.paint(c, Offset(PaperSheet.titleCenter.x - title.width / 2, PaperSheet.titleCenter.y - title.height / 2));
}

/// Fișa ca imagine (pentru teste: o „fotografie” perfectă).
Future<ui.Image> renderPaperSheet(FishSpecies s, {double pxPerMm = 4}) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(pxPerMm);
  paintPaperSheet(c, s);
  return rec.endRecording().toImage((PaperSheet.width * pxPerMm).round(), (PaperSheet.height * pxPerMm).round());
}

/// PDF-ul cu fișele modelelor [species], câte una pe pagină, A4 landscape.
Future<Uint8List> buildSheetsPdf(List<FishSpecies> species) async {
  final bold = pw.Font.ttf(await rootBundle.load('packages/$contentPackage/fonts/Nunito-ExtraBold.ttf'));
  final regular = pw.Font.ttf(await rootBundle.load('packages/$contentPackage/fonts/Nunito-SemiBold.ttf'));
  final doc = pw.Document(title: 'Licurici — pești de colorat', author: 'Licurici');
  final format = PdfPageFormat.a4.landscape;
  for (final s in species) {
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            pw.CustomPaint(size: PdfPoint(format.width, format.height), painter: (g, size) => _pdfSheet(g, size, s)),
            pw.Positioned(
              left: 0,
              right: 0,
              top: (PaperSheet.titleCenter.y - 6) * PdfPageFormat.mm,
              child: pw.Center(child: pw.Text(sheetTitle(s), style: pw.TextStyle(font: bold, fontSize: 26))),
            ),
            pw.Positioned(
              left: 0,
              right: 0,
              bottom: 9 * PdfPageFormat.mm,
              child: pw.Center(
                child: pw.Text(
                  'Colorează peștele cum vrei! Nu colora pătratele negre. Apoi arată-l lui Licurici cu camera.',
                  style: pw.TextStyle(font: regular, fontSize: 11, color: PdfColors.grey700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

void _pdfSheet(PdfGraphics g, PdfPoint size, FishSpecies s) {
  const mm = PdfPageFormat.mm;
  // PDF are originea jos-stânga; fișa e descrisă de sus în jos.
  double x(double v) => v * mm;
  double y(double v) => size.y - v * mm;
  void rect(double left, double top, double w, double h, PdfColor color) {
    g
      ..setFillColor(color)
      ..drawRect(x(left), y(top + h), w * mm, h * mm)
      ..fillPath();
  }

  for (final m in PaperSheet.corners) {
    const sz = PaperSheet.marker, u = sz / 7;
    rect(m.x - sz / 2, m.y - sz / 2, sz, sz, PdfColors.black);
    rect(m.x - sz / 2 + u, m.y - sz / 2 + u, sz - 2 * u, sz - 2 * u, PdfColors.white);
    rect(m.x - 1.5 * u, m.y - 1.5 * u, 3 * u, 3 * u, PdfColors.black);
  }
  for (final (cx, cy, sz, dark) in PaperSheet.codeCells(s)) {
    if (dark) rect(cx, cy, sz, sz, PdfColors.black);
  }

  // Conturul: linie groasă pe fiecare formă, apoi formele umplute cu alb — rămâne doar
  // marginea exterioară a siluetei (ca pe ecran).
  void path(List<math.Point<double>> pts, {bool closed = true}) {
    final segs = catmullRomBeziers(pts, closed: closed);
    final p0 = PaperSheet.boxToSheet(segs.first.$1.x, segs.first.$1.y);
    g.moveTo(x(p0.x), y(p0.y));
    for (final (_, c1, c2, b) in segs) {
      final a = PaperSheet.boxToSheet(c1.x, c1.y), bb = PaperSheet.boxToSheet(c2.x, c2.y), e = PaperSheet.boxToSheet(b.x, b.y);
      g.curveTo(x(a.x), y(a.y), x(bb.x), y(bb.y), x(e.x), y(e.y));
    }
    if (closed) g.closePath();
  }

  const ink = PdfColor.fromInt(0xFF3A3A3A);
  final outline = FishSpecies.outlineWidth * 2 * PaperSheet.boxScale * mm;
  g
    ..setStrokeColor(ink)
    ..setLineWidth(outline)
    ..setLineJoin(PdfLineJoin.round)
    ..setLineCap(PdfLineCap.round);
  for (final shape in s.shapes) {
    path(shape);
    g.strokePath();
  }
  g.setFillColor(PdfColors.white);
  for (final shape in s.shapes) {
    path(shape);
    g.fillPath();
  }
  g.setLineWidth(FishSpecies.detailWidth * PaperSheet.boxScale * mm);
  for (final d in s.details) {
    path(d, closed: false);
    g.strokePath();
  }
  final (eye, r) = s.eye;
  final e = PaperSheet.boxToSheet(eye.x, eye.y);
  g
    ..drawEllipse(x(e.x), y(e.y), r * PaperSheet.boxScale * mm, r * PaperSheet.boxScale * mm)
    ..strokePath();
}
