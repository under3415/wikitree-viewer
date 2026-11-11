import '../../core/failures.dart';
import '../../l10n/app_localizations.dart';

/// What to show a user about a [WikiTreeFailure]: the main line, and the second
/// line that says what to do next (empty when there is nothing useful to add).
class FailureText {
  const FailureText(this.message, this.hint);

  final String message;
  final String hint;
}

/// Translates a failure into words. Kept out of the failure types themselves so
/// they stay plain values that are safe to log.
FailureText describeFailure(AppLocalizations l10n, WikiTreeFailure failure) {
  switch (failure) {
    case InvalidKeyFailure(:final reason):
      return FailureText(
        _invalidKeyMessage(l10n, reason),
        _invalidKeyHint(l10n, reason),
      );
    case NotFoundFailure():
      return FailureText(l10n.errorNotFound, l10n.hintNotFound);
    case PrivateProfileFailure():
      return FailureText(l10n.errorPrivate, l10n.hintPrivate);
    case NetworkFailure(:final timedOut):
      return FailureText(
        timedOut ? l10n.errorTimeout : l10n.errorNetwork,
        l10n.hintNetwork,
      );
    case RateLimitFailure():
      return FailureText(l10n.errorRateLimit, l10n.hintRateLimit);
    case ServerFailure():
      return FailureText(l10n.errorServer, l10n.hintServer);
    case ParseFailure():
      return FailureText(l10n.errorParse, l10n.hintParse);
  }
}

String _invalidKeyMessage(AppLocalizations l10n, InvalidKeyReason reason) =>
    switch (reason) {
      InvalidKeyReason.empty => l10n.errorEmptyKey,
      InvalidKeyReason.tooLong => l10n.errorTooLongKey,
      InvalidKeyReason.noIdFound => l10n.errorNoIdFound,
      InvalidKeyReason.ambiguous => l10n.errorAmbiguousKey,
      InvalidKeyReason.spaceProfile => l10n.errorSpaceProfile,
      InvalidKeyReason.unsupportedHost => l10n.errorUnsupportedHost,
      InvalidKeyReason.malformed => l10n.errorMalformedKey,
    };

String _invalidKeyHint(AppLocalizations l10n, InvalidKeyReason reason) =>
    switch (reason) {
      InvalidKeyReason.empty ||
      InvalidKeyReason.noIdFound ||
      InvalidKeyReason.malformed => l10n.hintPasteLink,
      InvalidKeyReason.unsupportedHost => l10n.hintLinkStart,
      _ => '',
    };
