class ProfanityFilterService {
  static const List<String> _bannedWords = [
    // Spanish profanity / inappropriate terms
    'puta', 'puto', 'mierda', 'coño', 'pendejo', 'pendeja', 'cabron', 'cabrona',
    'maricon', 'verga', 'joder', 'bastardo', 'estupido', 'estupida', 'imbecil',
    'malparido', 'concha', 'chinga', 'chingar', 'zorra', 'maldito', 'maldita',

    // English profanity / inappropriate terms
    'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'cunt', 'dick', 'pussy',
    'whore', 'slut', 'nigger', 'faggot', 'idiot', 'stupid', 'dumbass', 'retard',
  ];

  /// Returns true if text contains any banned inappropriate words
  static bool hasProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      if (regex.hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Replaces any banned inappropriate words with asterisks (***) or paw icons
  static String sanitize(String text) {
    String clean = text;
    for (final word in _bannedWords) {
      final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      clean = clean.replaceAllMapped(regex, (match) {
        return '*' * match.group(0)!.length;
      });
    }
    return clean;
  }
}
