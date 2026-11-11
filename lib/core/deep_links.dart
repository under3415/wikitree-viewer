import 'dart:async';

import 'package:app_links/app_links.dart';

import '../data/key_parser.dart';
import '../util/wikitree_id_case.dart';
import 'constants.dart';
import 'failures.dart';

/// The links that open this app, and what they mean.
///
/// Two shapes are understood:
///
/// * `wikitreeviewer://person/Einstein-1` - registered in AndroidManifest.xml
///   and Info.plist, so it needs no server of our own.
/// * `https://www.wikitree.com/wiki/Einstein-1` - the profile link itself. The
///   app takes it when the system or a browser hands it over.
///
/// A verified `https://` link on our own domain (an Android App Link or an iOS
/// Universal Link) additionally needs `assetlinks.json` and an
/// `apple-app-site-association` file served from that domain - see README.md.
abstract final class DeepLink {
  /// Shared with the platform registration, so changing it means changing
  /// AndroidManifest.xml *and* Info.plist.
  static const String scheme = AppInfo.deepLinkScheme;

  static const String personHost = 'person';

  /// The link to share. It opens the app directly when it is installed.
  static String forKey(String wikiTreeId) =>
      '$scheme://$personHost/$wikiTreeId';

  /// The WikiTree ID inside [uri], or null when the link is not ours.
  static String? keyFrom(Uri uri) {
    if (uri.scheme == scheme) {
      // wikitreeviewer://person/Einstein-1, but also the short form
      // wikitreeviewer://Einstein-1 that people will inevitably type.
      final segments = uri.pathSegments.where((part) => part.isNotEmpty);
      final candidates = <String>[
        if (uri.host == personHost && segments.isNotEmpty) segments.first,
        if (uri.host != personHost && uri.host.isNotEmpty) uri.host,
        if (segments.isNotEmpty) segments.first,
      ];
      for (final candidate in candidates) {
        final key = _asKey(candidate);
        if (key != null) return key;
      }
      return null;
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      // KeyParser already decides which hosts are WikiTree and which are not.
      return _asKey(uri.toString());
    }

    return null;
  }

  static String? _asKey(String candidate) {
    try {
      // The URI spec lowercases hosts, and hand-written links are sloppy about
      // capitals, so put them back before checking the ID.
      return capitaliseWikiTreeId(KeyParser.parse(candidate).wikiTreeId);
    } on WikiTreeFailure {
      // Not a WikiTree ID, so this link is not one of ours.
      return null;
    }
  }
}

/// A mailbox for links, because the one that started the app arrives before any
/// screen exists to handle it.
class LinkInbox {
  LinkInbox() {
    _controller = StreamController<String>.broadcast(onListen: _flush);
  }

  late final StreamController<String> _controller;
  String? _pending;
  String? _last;

  /// WikiTree IDs waiting to be opened.
  Stream<String> get keys => _controller.stream;

  void add(String key) {
    if (_controller.isClosed) return;
    // The link that started the app can arrive on both paths, and opening the
    // same person twice would only stack two identical trees.
    if (key == _last) return;
    _last = key;
    if (_controller.hasListener) {
      _controller.add(key);
    } else {
      _pending = key;
    }
  }

  void _flush() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    // Hand it over once the listener is properly attached, not during onListen.
    scheduleMicrotask(() {
      if (!_controller.isClosed) _controller.add(pending);
    });
  }

  Future<void> close() => _controller.close();
}

/// Watches for links that open the app, whether it was started by one or is
/// already running.
class DeepLinkSource {
  DeepLinkSource({AppLinks? links}) {
    final source = links ?? AppLinks();
    _links = source;
    // Held as a future so an early completion cannot go unhandled.
    _initialLink = source.getInitialLink().catchError((Object _) => null);
  }

  final LinkInbox _inbox = LinkInbox();
  late final AppLinks _links;
  late final Future<Uri?> _initialLink;
  StreamSubscription<Uri>? _subscription;

  /// WikiTree IDs arriving from outside the app.
  Stream<String> get keys => _inbox.keys;

  /// Reads the link the app was started with, then keeps watching.
  Future<void> start() async {
    _subscription ??= _links.uriLinkStream.listen(
      _handle,
      onError: (Object _) {
        // A link that cannot be parsed is not worth interrupting anyone over.
      },
    );
    final initial = await _initialLink;
    if (initial != null) _handle(initial);
  }

  void _handle(Uri uri) {
    final key = DeepLink.keyFrom(uri);
    if (key != null) _inbox.add(key);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _inbox.close();
  }
}
