import 'package:flutter/services.dart';

bool _immersive = false;

bool isFullscreenActive() => _immersive;

Future<bool> toggleFullscreen() async {
  _immersive = !_immersive;
  try {
    await SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  } catch (_) {}
  return _immersive;
}
