import 'dart:async';
import 'dart:js_interop';

@JS('XMLHttpRequest')
extension type _XHR._(JSObject _) implements JSObject {
  external factory _XHR();
  external void open(String method, String url);
  external void setRequestHeader(String name, String value);
  external void send([JSAny? body]);
  external set timeout(int ms);
  external int get status;
  external String get responseText;
  external set onload(JSFunction? fn);
  external set onerror(JSFunction? fn);
  external set ontimeout(JSFunction? fn);
}

Future<({int status, String body})> httpRequest(
  String method,
  String url, {
  String? body,
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 30),
}) {
  final completer = Completer<({int status, String body})>();
  final xhr = _XHR();
  xhr.open(method, url);
  xhr.timeout = timeout.inMilliseconds;
  final hasContentType = headers?.keys.any(
        (k) => k.toLowerCase() == 'content-type',
      ) ??
      false;
  if (!hasContentType) {
    xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
  }
  headers?.forEach((key, value) {
    xhr.setRequestHeader(key, value);
  });
  xhr.onload = ((JSAny? _) {
    if (!completer.isCompleted) {
      completer.complete((status: xhr.status, body: xhr.responseText));
    }
  }).toJS;
  xhr.onerror = ((JSAny? _) {
    if (!completer.isCompleted) completer.completeError(Exception('Network error'));
  }).toJS;
  xhr.ontimeout = ((JSAny? _) {
    if (!completer.isCompleted) completer.completeError(Exception('Timeout'));
  }).toJS;
  xhr.send(body?.toJS);
  return completer.future;
}
