import 'dart:js_interop';

@JS('document')
external _Doc get _document;

extension type _Doc._(JSObject _) implements JSObject {
  external JSObject? get fullscreenElement;
  external _Elem? get documentElement;
  external JSPromise<JSAny?>? exitFullscreen();
}

extension type _Elem._(JSObject _) implements JSObject {
  external JSPromise<JSAny?>? requestFullscreen();
}

bool isFullscreenActive() {
  try {
    return _document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

Future<bool> toggleFullscreen() async {
  try {
    if (isFullscreenActive()) {
      final p = _document.exitFullscreen();
      if (p != null) await p.toDart;
      return false;
    } else {
      final p = _document.documentElement?.requestFullscreen();
      if (p != null) await p.toDart;
      return true;
    }
  } catch (_) {
    return isFullscreenActive();
  }
}
