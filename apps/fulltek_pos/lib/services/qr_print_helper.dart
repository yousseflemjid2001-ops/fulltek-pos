import 'qr_print_helper_stub.dart'
    if (dart.library.html) 'qr_print_helper_web.dart';

bool printQrStandeeHtml(String title, String bodyHtml) =>
    platformPrintQrStandeeHtml(title, bodyHtml);

bool openExternalUrl(String url) => platformOpenExternalUrl(url);
