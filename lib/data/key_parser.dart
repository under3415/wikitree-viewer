import '../core/failures.dart';

/// A WikiTree ID extracted from whatever the user typed or pasted.
class ParsedKey {
  const ParsedKey(this.wikiTreeId, {this.fromUrl = false});

  final String wikiTreeId;
  final bool fromUrl;

  @override
  String toString() => wikiTreeId;
}

/// Turns user input into a WikiTree ID.
///
/// Accepted:
///   * `Einstein-1`
///   * `einstein-1` (the repository retries with a capitalised surname)
///   * `https://www.wikitree.com/wiki/Einstein-1`
///   * `www.wikitree.com/wiki/Einstein-1`
///   * `Einstein-1 - WikiTree` (an ID inside pasted text)
///
/// Rejected with a helpful message: empty input, free-space pages, other
/// websites, ambiguous input and malformed codes.
abstract final class KeyParser {
  static const int maxInputLength = 300;

  /// A WikiTree ID: starts with a letter, then a surname, then `-#`.
  ///
  /// Anchored, and required to start with a letter, so dates like `1835-1910`
  /// are not mistaken for ids.
  ///
  /// "Letter" means any Unicode letter, not just A-Z: real ids such as
  /// `Marić-75` exist, and requiring ASCII turned tapping those people into a
  /// "that is not a WikiTree ID" error.
  static final RegExp idPattern = RegExp(
    r"^\p{L}[\p{L}\p{N}'._\-]*-\d{1,9}$",
    unicode: true,
  );

  static final RegExp _idInText = RegExp(
    r"(?<![\p{L}\p{N}'._\-])(\p{L}[\p{L}\p{N}'._\-]*-\d{1,9})(?![\p{L}\p{N}'._\-])",
    unicode: true,
  );

  static final RegExp _bareHost = RegExp(
    r'^(www\.|m\.)?wikitree\.com(/|$)',
    caseSensitive: false,
  );

  static final RegExp _spaceAroundHyphen = RegExp(r'\s-|-\s');

  static const Set<String> _knownHosts = <String>{
    'wikitree.com',
    'www.wikitree.com',
    'm.wikitree.com',
  };

  static ParsedKey parse(String raw) {
    if (raw.length > maxInputLength) {
      throw const InvalidKeyFailure(InvalidKeyReason.tooLong);
    }

    final text = _clean(raw);
    if (text.isEmpty) {
      throw const InvalidKeyFailure(InvalidKeyReason.empty);
    }

    final looksLikeUrl = text.contains('://') || _bareHost.hasMatch(text);
    if (looksLikeUrl) return _parseUrl(text);

    if (text.toLowerCase().startsWith('space:')) {
      throw const InvalidKeyFailure(InvalidKeyReason.spaceProfile);
    }

    if (idPattern.hasMatch(text)) return ParsedKey(text);

    // Surnames with spaces ("Van Der Berg-12") become underscore-separated ids.
    // Only when there is a single "-number" separator, so that two pasted ids
    // are not glued into one nonsense id.
    if (text.contains(' ')) {
      final collapsed = text.replaceAll(RegExp(r'\s+'), '_');
      final separators = RegExp(r'-\d').allMatches(collapsed).length;
      if (separators == 1 && idPattern.hasMatch(collapsed)) {
        return ParsedKey(collapsed);
      }
    }

    // An ID sitting inside pasted text, e.g. "Einstein-1 - WikiTree".
    final matches = _idInText
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toSet();
    if (matches.length == 1) return ParsedKey(matches.first);
    if (matches.length > 1) {
      throw const InvalidKeyFailure(InvalidKeyReason.ambiguous);
    }

    // "Einstein - 1" is a common typo; name it instead of failing vaguely.
    if (_spaceAroundHyphen.hasMatch(text)) {
      throw const InvalidKeyFailure(InvalidKeyReason.malformed);
    }

    throw const InvalidKeyFailure(InvalidKeyReason.noIdFound);
  }

  static ParsedKey _parseUrl(String text) {
    final candidate = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      throw const InvalidKeyFailure(InvalidKeyReason.noIdFound);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const InvalidKeyFailure(InvalidKeyReason.unsupportedHost);
    }

    final host = uri.host.toLowerCase();
    if (!_knownHosts.contains(host) && !host.endsWith('.wikitree.com')) {
      throw const InvalidKeyFailure(InvalidKeyReason.unsupportedHost);
    }

    final segments = uri.pathSegments;
    final wikiIndex = segments.indexWhere(
      (segment) => segment.toLowerCase() == 'wiki',
    );
    if (wikiIndex < 0 || wikiIndex + 1 >= segments.length) {
      throw const InvalidKeyFailure(InvalidKeyReason.noIdFound);
    }

    final candidateId = segments[wikiIndex + 1];
    if (candidateId.toLowerCase().startsWith('space:')) {
      throw const InvalidKeyFailure(InvalidKeyReason.spaceProfile);
    }
    if (!idPattern.hasMatch(candidateId)) {
      throw const InvalidKeyFailure(InvalidKeyReason.malformed);
    }
    return ParsedKey(candidateId, fromUrl: true);
  }

  /// Trims whitespace, invisible characters, wrapping quotes and trailing
  /// punctuation that comes along when people paste from chats or documents.
  static String _clean(String raw) {
    var text = raw
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\u200B-\u200D\u2060]'), '')
        .trim();

    while (text.isNotEmpty) {
      final last = text[text.length - 1];
      if ('.,;:!?)]}>\u00BB'.contains(last)) {
        text = text.substring(0, text.length - 1).trimRight();
      } else {
        break;
      }
    }

    while (text.isNotEmpty) {
      final first = text[0];
      if ('([{<\u00AB'.contains(first)) {
        text = text.substring(1).trimLeft();
      } else {
        break;
      }
    }

    if (text.length >= 2) {
      final startsWithQuote = text.startsWith('"') || text.startsWith("'");
      final endsWithQuote = text.endsWith('"') || text.endsWith("'");
      if (startsWithQuote && endsWithQuote) {
        text = text.substring(1, text.length - 1).trim();
      }
    }

    return text;
  }
}
