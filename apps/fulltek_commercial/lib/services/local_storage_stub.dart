final Map<String, String> _memStore = {};

String? readLocalValue(String key) => _memStore[key];

void writeLocalValue(String key, String value) {
  _memStore[key] = value;
}

void removeLocalValue(String key) {
  _memStore.remove(key);
}
