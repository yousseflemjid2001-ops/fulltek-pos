bool platformDownloadTextFile(String filename, String content,
        {String mimeType = 'text/csv;charset=utf-8'}) =>
    false;

bool platformPrintReportA4Html(String title, String bodyHtml) => false;

bool platformOpenExternalUrl(String url) => false;

Future<String?> platformRequestCurrentGpsMapsUrl() async => null;
