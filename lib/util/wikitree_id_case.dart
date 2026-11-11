/// Adds the capitals a WikiTree ID needs.
///
/// WikiTree IDs are case sensitive in the surname (`Einstein-1`, never
/// `einstein-1`), which is easy to miss on a phone keyboard. This only ever
/// *adds* capitals - the first letter, and the first letter after a hyphen,
/// apostrophe or space - so a name that is already right (`McDonald-1`) comes
/// back untouched.
String capitaliseWikiTreeId(String text) {
  final buffer = StringBuffer();
  var expectingCapital = true;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    if (character == '-' || character == "'" || character.trim().isEmpty) {
      buffer.write(character);
      expectingCapital = true;
      continue;
    }
    final isLetter = character.toUpperCase() != character.toLowerCase();
    if (expectingCapital && isLetter) {
      buffer.write(character.toUpperCase());
      expectingCapital = false;
      continue;
    }
    // Digits and punctuation keep the wait going, so `-1` and `--` are
    // harmless, but they never start a new word by themselves.
    expectingCapital = !isLetter;
    buffer.write(character);
  }
  return buffer.toString();
}
