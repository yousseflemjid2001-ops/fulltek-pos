// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

bool platformDownloadTextFile(
  String filename,
  String content, {
  String mimeType = 'text/csv;charset=utf-8',
}) {
  try {
    // Prefix UTF-8 BOM so Microsoft Excel opens French/Arabic accents cleanly
    final withBom = '\uFEFF$content';
    final blob = html.Blob([withBom], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

bool platformPrintReportA4Html(String title, String bodyHtml) {
  try {
    final escapedTitle = const HtmlEscape().convert(title);
    final docHtml = '''
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<title>$escapedTitle</title>
<style>
  @page { size: A4 portrait; margin: 12mm; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: 'Segoe UI', Arial, sans-serif;
    color: #0f172a;
    background: #ffffff;
    font-size: 12px;
    line-height: 1.4;
  }
  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 18px;
    background: #0f172a;
    color: #ffffff;
    margin-bottom: 14px;
  }
  .toolbar button {
    background: #10b981;
    color: #052e16;
    border: none;
    border-radius: 8px;
    padding: 8px 16px;
    font-weight: 800;
    cursor: pointer;
  }
  .page { max-width: 190mm; margin: 0 auto; padding: 0 6mm 12mm; }
  .header {
    display: flex;
    justify-content: space-between;
    border-bottom: 2px solid #0f172a;
    padding-bottom: 10px;
    margin-bottom: 14px;
  }
  .header h1 { margin: 0 0 4px; font-size: 18px; color: #0f172a; }
  .meta { font-size: 11px; color: #475569; }
  h2 {
    margin: 16px 0 6px;
    font-size: 13.5px;
    color: #0f172a;
    background: #f1f5f9;
    padding: 6px 10px;
    border-left: 4px solid #10b981;
  }
  table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
  th, td { border: 1px solid #cbd5e1; padding: 5px 8px; text-align: left; }
  th { background: #f8fafc; font-weight: 800; font-size: 11px; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  .total-row td { font-weight: 900; background: #ecfdf5; }
  @media print {
    .toolbar { display: none !important; }
    .page { padding: 0; }
  }
</style>
</head>
<body onload="setTimeout(() => { window.focus(); window.print(); }, 250);">
  <div class="toolbar">
    <div><b>$escapedTitle</b> · Rapport A4 / PDF</div>
    <button onclick="window.print()">🖨️ Imprimer / Enregistrer PDF</button>
  </div>
  <div class="page">$bodyHtml</div>
</body>
</html>
''';
    final blob = html.Blob([docHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}

bool platformOpenExternalUrl(String url) {
  try {
    if (url.trim().isEmpty) return false;
    html.window.open(url.trim(), '_blank');
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> platformRequestCurrentGpsMapsUrl() async {
  try {
    final pos = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
      maximumAge: Duration.zero,
    );
    final coords = pos.coords;
    final lat = coords?.latitude;
    final lng = coords?.longitude;
    if (lat == null || lng == null) return null;
    return 'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  } catch (_) {
    return null;
  }
}
