import 'dart:convert';
import 'dart:io';

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
}) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 6);
  try {
    final uri = Uri.parse(url);
    final req = await client.openUrl(method, uri);
    headers?.forEach((k, v) => req.headers.set(k, v));
    if (body != null) {
      final bytes = utf8.encode(body);
      req.headers.contentLength = bytes.length;
      req.add(bytes);
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return HttpBridgeResponse(res.statusCode, text);
  } finally {
    client.close(force: true);
  }
}
