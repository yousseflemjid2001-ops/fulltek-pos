String? lastExportedFileName;
String? lastPrintedHtmlTitle;

bool downloadCsvFile(String filename, String csvContent) {
  lastExportedFileName = filename;
  return true;
}

bool openA4PrintWindow(String title, String bodyHtml) {
  lastPrintedHtmlTitle = title;
  return true;
}
