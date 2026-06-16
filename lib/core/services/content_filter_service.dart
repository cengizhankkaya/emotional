/// A service that filters objectionable content from chat messages.
///
/// Provides profanity detection and text masking for both English and Turkish.
class ContentFilterService {
  ContentFilterService._();
  static final ContentFilterService _instance = ContentFilterService._();
  static ContentFilterService get instance => _instance;

  /// Combined profanity word list (EN + TR). Kept minimal and focused on
  /// clearly objectionable terms. This list should be expanded over time.
  static const List<String> _profanityList = [
    // English
    'fuck', 'shit', 'ass', 'asshole', 'bitch', 'bastard', 'dick', 'pussy',
    'cunt', 'nigger', 'nigga', 'faggot', 'retard', 'whore', 'slut',
    'motherfucker', 'cocksucker', 'dumbass', 'bullshit',
    // Turkish
    'amk', 'aq', 'orospu', 'piç', 'siktir', 'yarrak', 'göt', 'sikik',
    'amına', 'ananı', 'pezevenk', 'kahpe', 'gavat', 'ibne', 'gerizekalı',
    'mal', 'salak', 'aptal', 'dangalak',
  ];

  /// Returns `true` if the [text] contains any profanity.
  bool containsProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _profanityList) {
      // Use word boundary matching so "class" doesn't match "ass"
      final pattern = RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false);
      if (pattern.hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Replaces profanity in [text] with asterisks (`***`).
  String filterText(String text) {
    String result = text;
    for (final word in _profanityList) {
      final pattern = RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false);
      result = result.replaceAll(pattern, '***');
    }
    return result;
  }

  /// Returns `true` if the entire message should be blocked (e.g. the message
  /// is predominantly profanity after filtering).
  bool shouldBlockMessage(String text) {
    final filtered = filterText(text).trim();
    // If the filtered result is only asterisks or very short, block it
    if (filtered.isEmpty) return true;
    final nonAsterisk = filtered.replaceAll('*', '').replaceAll(' ', '');
    return nonAsterisk.isEmpty;
  }
}
