class ProfanityFilterService {
  static const List<String> _bannedWords = [
    // Spanish profanity / offensive expressions & regional slang
    'puta', 'puto', 'putita', 'puton', 'putas', 'putos',
    'mierda', 'mierdas', 'mrd',
    'coño', 'cono', 'coños',
    'pendejo', 'pendeja', 'pendejos', 'pendejas',
    'cabron', 'cabrona', 'cabrones', 'cabronas',
    'maricon', 'marica', 'maricones',
    'verga', 'vergas', 'vergazo',
    'joder', 'jodete', 'jodido', 'jodida',
    'bastardo', 'bastarda', 'bastardos',
    'estupido', 'estupida', 'estupidos', 'estupidas',
    'imbecil', 'imbeciles',
    'malparido', 'malparida', 'malparidos',
    'concha', 'conchudo', 'conchuda', 'conchetumadre', 'conchaetumadre',
    'chinga', 'chingar', 'chingada', 'chingado', 'chingados',
    'culiao', 'culiaos', 'culero', 'culeros', 'culo',
    'zorra', 'zorras',
    'maldito', 'maldita', 'malditos', 'malditas',
    'hdp', 'hijoputa', 'hijo de puta', 'hija de puta', 'hp',
    'chucha', 'carajo', 'mamaguevo', 'mamahuevo', 'carechimba', 'gonorrea',

    // English profanity / offensive expressions
    'fuck', 'fucking', 'fucker', 'fucked', 'fuckoff',
    'shit', 'shits', 'bullshit',
    'bitch', 'bitches', 'bitchy',
    'asshole', 'assholes', 'ass',
    'bastard', 'bastards',
    'cunt', 'cunts',
    'dick', 'dicks', 'dickhead',
    'pussy', 'pussies',
    'whore', 'whores',
    'slut', 'sluts',
    'nigger', 'nigga',
    'faggot', 'fag',
    'idiot', 'idiots',
    'retard', 'retarded',
    'dumbass',
  ];

  /// Normalize string removing diacritics, leetspeak, duplicate sequences, and special symbols
  static String normalize(String text) {
    var s = text.toLowerCase();

    // Replace common diacritics & accents
    s = s
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ñ', 'n');

    // Replace leetspeak characters
    s = s
        .replaceAll('@', 'a')
        .replaceAll('4', 'a')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('|', 'i')
        .replaceAll('0', 'o')
        .replaceAll(r'$', 's')
        .replaceAll('5', 's')
        .replaceAll('7', 't');

    // Collapse consecutive repeating characters (e.g. 'puuuuta' -> 'puta', 'fffffuck' -> 'fuck')
    s = s.replaceAllMapped(RegExp(r'(.)\1{2,}'), (match) => match.group(1)!);

    return s;
  }

  /// Returns true if text contains any banned inappropriate words
  static bool hasProfanity(String text) {
    if (text.trim().isEmpty) return false;

    final norm = normalize(text);
    // Also prepare a version stripped of all non-alphanumeric (to catch "p.u.t.a" or "p u t a")
    final compact = norm.replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final word in _bannedWords) {
      final cleanWord = normalize(word).replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanWord.isEmpty) continue;

      // 1. Check exact word boundary match on normalized text
      final wordRegex = RegExp(r'(?<=^|[^a-z0-9])' + RegExp.escape(cleanWord) + r'(?=[^a-z0-9]|$)', caseSensitive: false);
      if (wordRegex.hasMatch(norm)) {
        return true;
      }

      // 2. For words of 4+ characters, also check compacted version to catch spacing obfuscations (e.g. "p u t a")
      if (cleanWord.length >= 4 && compact.contains(cleanWord)) {
        return true;
      }
    }

    return false;
  }

  /// Replaces any banned inappropriate words with asterisks (***)
  static String sanitize(String text) {
    if (text.trim().isEmpty) return text;
    String clean = text;

    for (final word in _bannedWords) {
      // Find matches on the word ignoring case and diacritics
      final regex = RegExp(r'(?<=^|[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ])' + RegExp.escape(word) + r'(?=[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]|$)', caseSensitive: false);
      clean = clean.replaceAllMapped(regex, (match) {
        return '*' * match.group(0)!.length;
      });
    }
    return clean;
  }
}
