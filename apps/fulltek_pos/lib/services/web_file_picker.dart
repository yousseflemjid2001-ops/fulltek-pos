import 'web_file_picker_stub.dart'
    if (dart.library.html) 'web_file_picker_web.dart';

/// Opens a browser file chooser for an image (PNG/JPG/WEBP) and returns
/// a base64 `data:image/...;base64,...` string (or null if cancelled / too large).
Future<String?> pickLogoImageDataUrl({int maxBytes = 600000}) =>
    platformPickLogoImageDataUrl(maxBytes: maxBytes);
