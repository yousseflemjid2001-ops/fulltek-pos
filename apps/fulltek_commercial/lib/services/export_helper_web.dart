// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

String? lastExportedFileName;
String? lastPrintedHtmlTitle;

bool downloadCsvFile(String filename, String csvContent) {
  lastExportedFileName = filename;
  try {
    final bom = '\uFEFF$csvContent';
    final bytes = utf8.encode(bom);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
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

bool openA4PrintWindow(String title, String bodyHtml) {
  lastPrintedHtmlTitle = title;
  try {
    final escapedTitle = const HtmlEscape().convert(title);
    final docHtml = '''
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>$escapedTitle</title>
<style>
  @page { size: A4; margin: 14mm; }
  body { font-family: 'Segoe UI', system-ui, sans-serif; color: #0f172a; margin: 0; font-size: 12px; }
  .hdr { display: flex; justify-content: space-between; border-bottom: 2px solid #0f172a; padding-bottom: 10px; margin-bottom: 16px; }
  .brand { font-size: 18px; font-weight: 900; color: #0f172a; }
  .meta { text-align: right; font-size: 11px; color: #475569; }
  table { width: 100%; border-collapse: collapse; margin: 12px 0; }
  th { background: #0f172a; color: #fff; text-align: left; padding: 7px 8px; font-size: 11px; }
  td { border-bottom: 1px solid #e2e8f0; padding: 7px 8px; font-size: 11.5px; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
  .totals { width: 280px; margin-left: auto; margin-top: 12px; }
  .totals tr td { padding: 5px 8px; }
  .totals .grand { font-weight: 900; font-size: 13px; background: #f1f5f9; }
  .footer { margin-top: 24px; border-top: 1px solid #e2e8f0; padding-top: 8px; font-size: 10px; color: #64748b; text-align: center; }
</style>
</head>
<body onload="window.focus(); window.print();">
$bodyHtml
<div class="footer">Propulsé par Full·Tek Gestion Commerciale · Mauritanie (MRU)</div>
</body>
</html>
''';
    final blob = html.Blob([docHtml], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank', 'width=900,height=750');
    return true;
  } catch (_) {
    return false;
  }
}
