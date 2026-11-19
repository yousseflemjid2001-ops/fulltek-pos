import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<({int status, String body})> httpRequest(
  String method,
  String url, {
  String? body,
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client.openUrl(method, Uri.parse(url));
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    headers?.forEach((key, value) {
      req.headers.set(key, value);
    });
    if (body != null) {
      final bytes = utf8.encode(body);
      req.headers.contentLength = bytes.length;
      req.add(bytes);
    }
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join().timeout(timeout);
    return (status: res.statusCode, body: text);
  } finally {
    client.close(force: true);
  }
}
