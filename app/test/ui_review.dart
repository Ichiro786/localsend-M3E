import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const uiReviewBoundaryKey = ValueKey('ui-review-boundary');

Future<void> loadUiReviewFonts() async {
  if (!const bool.fromEnvironment('UI_REVIEW')) return;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT is required for UI review renders');
  final loader = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
    final file = File('$root/bin/cache/artifacts/material_fonts/$name');
    loader.addFont(file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  final iconFile = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  icons.addFont(iconFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
  await icons.load();
  final fallback = FontLoader('UiReviewFallback');
  final fallbackFile = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  fallback.addFont(fallbackFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
  await fallback.load();
}

ThemeData uiReviewTheme(ThemeData theme) {
  if (!const bool.fromEnvironment('UI_REVIEW')) return theme;
  return theme.copyWith(textTheme: theme.textTheme.apply(fontFamilyFallback: const ['UiReviewFallback']));
}

Future<void> captureUiReview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UI_REVIEW')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(uiReviewBoundaryKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-review');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
