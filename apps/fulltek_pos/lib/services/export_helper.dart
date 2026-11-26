import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart';

bool downloadTextFile(String filename, String content, {String mimeType = 'text/csv;charset=utf-8'}) =>
    platformDownloadTextFile(filename, content, mimeType: mimeType);

bool printReportA4Html(String title, String bodyHtml) =>
    platformPrintReportA4Html(title, bodyHtml);

bool openExternalUrl(String url) => platformOpenExternalUrl(url);

Future<String?> requestCurrentGpsMapsUrl() => platformRequestCurrentGpsMapsUrl();
