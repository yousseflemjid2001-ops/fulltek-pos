import 'dart:io';
import 'file_reader_types.dart';

bool get canPickCatalogFileNatively => false;

Future<PickedCatalogFile?> pickCatalogFilePlatform() async => null;

Future<PickedCatalogFile> readCatalogFilePathPlatform(String path) async {
  final cleanPath = path.trim();
  if (cleanPath.isEmpty) {
    throw const FormatException('Chemin du fichier requis');
  }
  final file = File(cleanPath);
  if (!await file.exists()) {
    throw FileSystemException('Fichier introuvable', cleanPath);
  }
  final bytes = await file.readAsBytes();
  final filename = cleanPath.split(RegExp(r'[/\\]')).last;
  return parseCatalogFileBytes(filename, bytes);
}
