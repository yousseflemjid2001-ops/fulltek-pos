import 'file_reader_io.dart'
    if (dart.library.js_interop) 'file_reader_web.dart' as impl;
import 'file_reader_types.dart';

export 'file_reader_types.dart';

bool get canPickCatalogFileNatively =>
    FileReaderBridge.pickerOverride != null || impl.canPickCatalogFileNatively;

Future<PickedCatalogFile?> pickCatalogFile() {
  final override = FileReaderBridge.pickerOverride;
  if (override != null) return override();
  return impl.pickCatalogFilePlatform();
}

Future<PickedCatalogFile> readCatalogFileFromPath(String path) =>
    impl.readCatalogFilePathPlatform(path);
