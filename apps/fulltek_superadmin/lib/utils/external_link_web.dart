import 'dart:js_interop';

@JS('window.open')
external void _jsWindowOpen(String url, String target);

void openExternalUrl(String url) {
  _jsWindowOpen(url, '_blank');
}

bool get canOpenUrlDirectly => true;
