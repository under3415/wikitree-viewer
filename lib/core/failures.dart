/// Everything that can go wrong while talking to WikiTree, expressed as a
/// small, privacy-safe value type.
///
/// These objects deliberately never carry the WikiTree ID, the request URL or
/// any profile field, because they are forwarded to crash reporting. They also
/// carry no wording: `describeFailure` in `lib/ui/format/failure_text.dart`
/// turns them into a language the reader understands.
library;

enum WikiTreeFailureCode {
  invalidKey,
  notFound,
  privateProfile,
  network,
  rateLimited,
  server,
  parse,
}

enum InvalidKeyReason {
  empty,
  tooLong,
  noIdFound,
  ambiguous,
  spaceProfile,
  unsupportedHost,
  malformed,
}

sealed class WikiTreeFailure implements Exception {
  const WikiTreeFailure({this.httpStatus});

  final int? httpStatus;

  WikiTreeFailureCode get code;

  /// Whether trying the same action again can reasonably succeed.
  bool get retryable => false;

  @override
  String toString() =>
      'WikiTreeFailure(${code.name}${httpStatus == null ? '' : ', http=$httpStatus'})';
}

final class InvalidKeyFailure extends WikiTreeFailure {
  const InvalidKeyFailure(this.reason);

  final InvalidKeyReason reason;

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.invalidKey;
}

final class NotFoundFailure extends WikiTreeFailure {
  const NotFoundFailure({super.httpStatus});

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.notFound;
}

final class PrivateProfileFailure extends WikiTreeFailure {
  const PrivateProfileFailure({super.httpStatus});

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.privateProfile;
}

final class NetworkFailure extends WikiTreeFailure {
  const NetworkFailure({this.timedOut = false});

  final bool timedOut;

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.network;

  @override
  bool get retryable => true;
}

final class RateLimitFailure extends WikiTreeFailure {
  const RateLimitFailure({super.httpStatus = 429});

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.rateLimited;

  @override
  bool get retryable => true;
}

final class ServerFailure extends WikiTreeFailure {
  const ServerFailure({super.httpStatus});

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.server;

  @override
  bool get retryable => true;
}

final class ParseFailure extends WikiTreeFailure {
  const ParseFailure();

  @override
  WikiTreeFailureCode get code => WikiTreeFailureCode.parse;
}
