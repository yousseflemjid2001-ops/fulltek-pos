import 'web_printer_stub.dart'
    if (dart.library.html) 'web_printer_web.dart';

bool printThermal80mm(
  String title,
  String receiptText, {
  String? logoDataUrl,
  String logoPosition = 'center',
}) =>
    platformPrint80mm(
      title,
      receiptText,
      logoDataUrl: logoDataUrl,
      logoPosition: logoPosition,
    );
