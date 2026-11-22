/// Lower-case, diacritic-free form for search ("İstanbul" -> "istanbul", "Ataşehir" -> "atasehir").
String foldTr(String input) {
  const map = <String, String>{
    'İ': 'i', 'I': 'i', 'ı': 'i', 'Ş': 's', 'ş': 's', 'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u', 'Ö': 'o', 'ö': 'o', 'Ç': 'c', 'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(map[ch] ?? ch.toLowerCase());
  }
  return buffer.toString();
}

const String _trAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

/// Rank of one character in Turkish alphabetical order. Characters outside the alphabet
/// (space, digits, punctuation) sort before letters.
int _rank(String ch) {
  switch (ch) {
    case 'I':
      ch = 'ı';
    case 'İ':
      ch = 'i';
    case 'Â':
    case 'â':
      ch = 'a';
    case 'Î':
    case 'î':
      ch = 'i';
    case 'Û':
    case 'û':
      ch = 'u';
    default:
      ch = ch.toLowerCase();
  }
  final index = _trAlphabet.indexOf(ch);
  if (index >= 0) return 1000 + index;
  final code = ch.codeUnitAt(0);
  // q, w, x are not Turkish letters; keep them after the Turkish ones in a stable place.
  return code < 1000 ? code : 2000 + code;
}

/// Compares two strings by the Turkish alphabet:
/// a b c ç d e f g ğ h ı i j k l m n o ö p r s ş t u ü v y z.
int compareTr(String a, String b) {
  final ar = a.runes.map(String.fromCharCode).toList();
  final br = b.runes.map(String.fromCharCode).toList();
  final n = ar.length < br.length ? ar.length : br.length;
  for (var i = 0; i < n; i++) {
    final diff = _rank(ar[i]).compareTo(_rank(br[i]));
    if (diff != 0) return diff;
  }
  return ar.length.compareTo(br.length);
}
