import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/crash_reporter.dart';
import 'core/deep_links.dart';
import 'data/wikitree_api.dart';
import 'data/wikitree_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Month names for every language the app speaks, so a date reads correctly the
  // first time a card is drawn rather than falling back to English.
  await initializeDateFormatting();

  // Anonymous crash reports only. This never blocks startup for long, and the
  // app runs normally when Firebase is unavailable.
  await CrashReporter.start();

  // A link that opened the app is read here; later ones arrive on the stream.
  final links = DeepLinkSource();
  await links.start();

  runApp(
    WikiTreeViewerApp(
      repository: WikiTreeRepository(api: HttpWikiTreeApi()),
      links: links.keys,
    ),
  );
}
