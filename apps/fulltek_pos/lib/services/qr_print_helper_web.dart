// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

bool platformPrintQrStandeeHtml(String title, String bodyHtml) {
  try {
    final escapedTitle = const HtmlEscape().convert(title);
    final docHtml = '''
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<title>$escapedTitle</title>
<style>
  @page { size: A4 portrait; margin: 10mm; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: 'Segoe UI', Arial, sans-serif;
    color: #0f172a;
    background: #ffffff;
  }
  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 16px;
    background: #0f172a;
    color: #ffffff;
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
  .grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 10mm;
    padding: 8mm;
  }
  .card {
    border: 2px dashed #cbd5e1;
    border-radius: 14px;
    padding: 16px 14px;
    text-align: center;
    page-break-inside: avoid;
    break-inside: avoid;
  }
  .card-single {
    max-width: 140mm;
    margin: 16mm auto;
    border: 2px solid #0f172a;
    border-radius: 18px;
    padding: 28px 22px;
    text-align: center;
  }
  .rest-name {
    font-size: 16px;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #0f172a;
    margin-bottom: 4px;
  }
  .badge {
    display: inline-block;
    background: #0f172a;
    color: #34d399;
    padding: 4px 14px;
    border-radius: 999px;
    font-weight: 900;
    font-size: 13px;
    margin: 6px 0 10px;
  }
  .qr-wrap {
    display: flex;
    justify-content: center;
    margin: 8px 0 10px;
  }
  .cta-fr {
    font-size: 12.5px;
    font-weight: 800;
    color: #0f172a;
  }
  .cta-ar {
    font-size: 13px;
    font-weight: 800;
    color: #334155;
    margin-top: 3px;
    direction: rtl;
  }
  .url-foot {
    font-size: 9.5px;
    color: #64748b;
    margin-top: 8px;
    word-break: break-all;
  }
  @media print {
    .toolbar { display: none !important; }
    .grid { padding: 0; }
  }
</style>
</head>
<body onload="setTimeout(() => { window.focus(); window.print(); }, 250);">
  <div class="toolbar">
    <div><b>$escapedTitle</b> · Prêt à imprimer (A4)</div>
    <button onclick="window.print()">🖨️ Imprimer</button>
  </div>
  $bodyHtml
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
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
