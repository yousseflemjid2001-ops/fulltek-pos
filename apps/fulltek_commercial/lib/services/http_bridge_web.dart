// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

class HttpBridgeResponse {
  final int statusCode;
  final String body;
  const HttpBridgeResponse(this.statusCode, this.body);
}

Future<HttpBridgeResponse> httpBridgeRequest(
  String method,
  String url, {
  Map<String, String>? headers,
  String? body,
}) {
  final completer = Completer<HttpBridgeResponse>();
  final req = html.HttpRequest();
  req.open(method, url);
  headers?.forEach((k, v) => req.setRequestHeader(k, v));
  req.onLoadEnd.listen((_) {
    completer.complete(
      HttpBridgeResponse(req.status ?? 0, req.responseText ?? ''),
    );
  });
  req.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('Network error calling $url'));
    }
  });
  req.send(body);
  return completer.future;
}
