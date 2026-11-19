import 'dart:convert';
import 'dart:typed_data';

class PickedCatalogFile {
  final String filename;
  final String format; // 'csv' | 'xlsx'
  final String? csvText;
  final String? contentBase64;
  final int byteLength;

  const PickedCatalogFile({
    required this.filename,
    required this.format,
    this.csvText,
    this.contentBase64,
    this.byteLength = 0,
  });
}

typedef CatalogFilePicker = Future<PickedCatalogFile?> Function();

class FileReaderBridge {
  /// Injectable override for deterministic widget/unit tests without OS dialogs.
  static CatalogFilePicker? pickerOverride;
}

/// Parses raw file bytes into a [PickedCatalogFile] based on extension.
/// Supports `.csv` (UTF-8 with optional BOM or Latin-1 fallback) and `.xlsx` (Base64).
PickedCatalogFile parseCatalogFileBytes(String filename, List<int> rawBytes) {
  final cleanName = filename.trim();
  if (cleanName.isEmpty) {
    throw const FormatException('Nom de fichier manquant');
  }
  if (rawBytes.isEmpty) {
    throw const FormatException('Le fichier sélectionné est vide');
  }
  final lower = cleanName.toLowerCase();
  if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
    String text;
    try {
      text = utf8.decode(rawBytes, allowMalformed: false);
    } on FormatException {
      // Excel FR frequently exports Windows-1252 / Latin-1 CSVs
      text = latin1.decode(rawBytes);
    }
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    return PickedCatalogFile(
      filename: cleanName,
      format: 'csv',
      csvText: text,
      byteLength: rawBytes.length,
    );
  }
  if (lower.endsWith('.xlsx')) {
    return PickedCatalogFile(
      filename: cleanName,
      format: 'xlsx',
      contentBase64: base64Encode(Uint8List.fromList(rawBytes)),
      byteLength: rawBytes.length,
    );
  }
  throw const FormatException(
    'Format non supporté : sélectionnez un fichier .csv ou .xlsx',
  );
}
