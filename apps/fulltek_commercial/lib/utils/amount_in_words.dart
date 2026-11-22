/// Converts a numeric amount in MRU to French legal words for B2B invoices.
/// Example: 480000 -> "Quatre cent quatre-vingt mille ouguiyas"
String amountToFrenchWords(double amount) {
  final n = amount.round().abs();
  if (n == 0) return 'Zéro ouguiya';
  final words = _convertInt(n).trim();
  final capitalized =
      words.isEmpty ? 'Zéro' : '${words[0].toUpperCase()}${words.substring(1)}';
  final unit = n > 1 ? 'ouguiyas' : 'ouguiya';
  return '$capitalized $unit';
}

String _convertInt(int n) {
  if (n == 0) return '';
  if (n < 1000) return _under1000(n);
  if (n < 1000000) {
    final thousands = n ~/ 1000;
    final rem = n % 1000;
    final prefix = thousands == 1 ? 'mille' : '${_under1000(thousands)} mille';
    return rem == 0 ? prefix : '$prefix ${_under1000(rem)}';
  }
  final millions = n ~/ 1000000;
  final rem = n % 1000000;
  final mWord = millions == 1 ? 'un million' : '${_under1000(millions)} millions';
  return rem == 0 ? mWord : '$mWord ${_convertInt(rem)}';
}

String _under1000(int n) {
  const units = [
    '',
    'un',
    'deux',
    'trois',
    'quatre',
    'cinq',
    'six',
    'sept',
    'huit',
    'neuf',
    'dix',
    'onze',
    'douze',
    'treize',
    'quatorze',
    'quinze',
    'seize',
    'dix-sept',
    'dix-huit',
    'dix-neuf',
  ];
  const tens = [
    '',
    '',
    'vingt',
    'trente',
    'quarante',
    'cinquante',
    'soixante',
    'soixante',
    'quatre-vingt',
    'quatre-vingt',
  ];

  final buf = StringBuffer();
  final h = n ~/ 100;
  final r = n % 100;

  if (h > 0) {
    if (h == 1) {
      buf.write('cent');
    } else {
      buf.write('${units[h]} cent${r == 0 ? 's' : ''}');
    }
    if (r > 0) buf.write(' ');
  }

  if (r > 0) {
    if (r < 20) {
      buf.write(units[r]);
    } else {
      final t = r ~/ 10;
      final u = r % 10;
      if (t == 7 || t == 9) {
        final base = tens[t];
        final teen = 10 + u;
        if (t == 7 && u == 1) {
          buf.write('$base et onze');
        } else {
          buf.write('$base-${units[teen]}');
        }
      } else if (t == 8) {
        if (u == 0) {
          buf.write('quatre-vingts');
        } else {
          buf.write('quatre-vingt-${units[u]}');
        }
      } else {
        final base = tens[t];
        if (u == 0) {
          buf.write(base);
        } else if (u == 1) {
          buf.write('$base et un');
        } else {
          buf.write('$base-${units[u]}');
        }
      }
    }
  }
  return buf.toString();
}
