// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

bool platformPrint80mm(
  String title,
  String receiptText, {
  String? logoDataUrl,
  String logoPosition = 'center',
}) {
  try {
    final escapedTitle = const HtmlEscape().convert(title);
    final escapedBody = const HtmlEscape().convert(receiptText);
    final hasLogo =
        logoDataUrl != null && logoDataUrl.trim().startsWith('data:image/');
    final alignCss = logoPosition == 'left'
        ? 'left'
        : (logoPosition == 'right' ? 'right' : 'center');
    final logoBlock = hasLogo
        ? '<div class="logo-wrap" style="text-align:$alignCss;"><img src="$logoDataUrl" alt="Logo" /></div>'
        : '';
    final docHtml = '''
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>$escapedTitle</title>
<style>
  @page { size: 80mm auto; margin: 3mm; }
  body {
    font-family: 'Courier New', Courier, monospace;
    font-size: 12px;
    line-height: 1.35;
    width: 74mm;
    margin: 0 auto;
    color: #000;
    background: #fff;
  }
  .logo-wrap {
    margin: 0 0 6px 0;
  }
  .logo-wrap img {
    max-width: 54mm;
    max-height: 22mm;
    object-fit: contain;
    filter: grayscale(100%) contrast(125%);
  }
  pre {
    white-space: pre-wrap;
    word-break: break-word;
    margin: 0;
  }
  @media print {
    .no-print { display: none; }
  }
</style>
</head>
<body onload="window.focus(); window.print();">
  $logoBlock
  <pre>$escapedBody</pre>
</body>
</html>
''';
    final blob = html.Blob([docHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank', 'width=360,height=640');
    return true;
  } catch (_) {
    return false;
  }
}
