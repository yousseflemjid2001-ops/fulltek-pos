import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'file_reader_types.dart';

@JS('document')
external _JSDocument get _document;

extension type _JSDocument._(JSObject _) implements JSObject {
  external _JSInputElement createElement(String tagName);
  external _JSBodyElement? get body;
}

extension type _JSBodyElement._(JSObject _) implements JSObject {
  external void appendChild(_JSInputElement node);
}

extension type _JSStyle._(JSObject _) implements JSObject {
  external set display(String value);
}

extension type _JSInputElement._(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external _JSStyle get style;
  external set onchange(JSFunction? fn);
  external set oncancel(JSFunction? fn);
  external _JSFileList? get files;
  external void click();
  external void remove();
}

extension type _JSFileList._(JSObject _) implements JSObject {
  external _JSFile? item(int index);
}

extension type _JSFile._(JSObject _) implements JSObject {
  external String get name;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

bool get canPickCatalogFileNatively => true;

Future<PickedCatalogFile?> pickCatalogFilePlatform() {
  final completer = Completer<PickedCatalogFile?>();
  final input = _document.createElement('input')
    ..type = 'file'
    ..accept =
        '.csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  input.style.display = 'none';
  _document.body?.appendChild(input);

  void cleanup() {
    input.onchange = null;
    input.oncancel = null;
    input.remove();
  }

  input.onchange = ((JSAny? _) {
    () async {
      try {
        final file = input.files?.item(0);
        if (file == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final jsBuffer = await file.arrayBuffer().toDart;
        final bytes = Uint8List.view(jsBuffer.toDart);
        final parsed = parseCatalogFileBytes(file.name, bytes);
        if (!completer.isCompleted) completer.complete(parsed);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        cleanup();
      }
    }();
  }).toJS;

  input.oncancel = ((JSAny? _) {
    cleanup();
    if (!completer.isCompleted) completer.complete(null);
  }).toJS;

  input.click();
  return completer.future;
}

Future<PickedCatalogFile> readCatalogFilePathPlatform(String path) =>
    Future.error(
      UnsupportedError('Lecture par chemin local indisponible sur Web'),
    );
