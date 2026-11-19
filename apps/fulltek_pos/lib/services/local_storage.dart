import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart';

String? localStorageRead(String key) => readLocalValue(key);
void localStorageWrite(String key, String value) => writeLocalValue(key, value);
void localStorageRemove(String key) => removeLocalValue(key);
