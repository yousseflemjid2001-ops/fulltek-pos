// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<String?> platformPickLogoImageDataUrl({int maxBytes = 600000}) async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp'
    ..multiple = false;

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    if (file.size > maxBytes) {
      if (!completer.isCompleted) completer.complete('__TOO_LARGE__');
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (!completer.isCompleted) {
        completer.complete(result is String ? result : null);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
