/// Renders the launcher-icon masters from the SVG artwork.
///
/// Run it whenever the art changes:
///
/// ```
/// flutter test tool/make_launcher_icons.dart
/// dart run flutter_launcher_icons
/// ```
///
/// It is a test rather than a plain script because that is the cheapest way to
/// get a real Flutter canvas: the PNGs are drawn by the same renderer the app
/// uses for the emblem, so the icon in the launcher and the emblem on the first
/// screen always match.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const String _source = 'art/wikitree-reader-logo.svg';

/// Side of the master images, in pixels.
const int _master = 1024;

/// How much of the icon the emblem takes up in the adaptive (Android) version.
///
/// Launchers crop the foreground to their own shape, so an emblem that filled
/// the square would lose its edge. `flutter_launcher_icons` also insets the
/// foreground by 16%, so 0.78 here leaves the disc at about two thirds of the
/// tile - the safe zone Android guarantees to show.
const double _safeZone = 0.78;

Future<PictureInfo> _load() async {
  final svg = File(_source).readAsStringSync();
  return vg.loadPicture(SvgStringLoader(svg), null);
}

/// Draws the emblem onto a [_master]-sided canvas, optionally shrunk to make
/// room for a launcher to crop. The vector is rasterised at the final size, so
/// the small Android densities stay sharp.
Future<void> _write(PictureInfo info, String path, {double scale = 1}) async {
  final side = _master * scale;
  final offset = (_master - side) / 2;
  final ratio = side / info.size.width;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(offset, offset)
    ..scale(ratio);
  canvas.drawPicture(info.picture);

  final image = await recorder.endRecording().toImage(_master, _master);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('renders the launcher icon masters', (tester) async {
    // No widget tree is needed: the picture is rasterised directly, which also
    // keeps the output free of the test font. `runAsync` lets the engine do the
    // real work of encoding the PNGs.
    await tester.runAsync(() async {
      final info = await _load();

      await _write(info, 'art/icon/wikitree-reader-logo-1024.png');
      await _write(
        info,
        'art/icon/wikitree-reader-logo-foreground-1024.png',
        scale: _safeZone,
      );

      info.picture.dispose();
    });

    expect(File('art/icon/wikitree-reader-logo-1024.png').existsSync(), isTrue);
    expect(
      File('art/icon/wikitree-reader-logo-foreground-1024.png').existsSync(),
      isTrue,
    );
  });
}
