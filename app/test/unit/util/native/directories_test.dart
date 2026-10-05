import 'dart:io' show Directory, Link, Platform;

import 'package:localsend_app/util/native/directories.dart';
import 'package:test/test.dart';

void main() {
  test(
    'resolves a symlinked Downloads directory',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'localsend-download-path-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));

      final realDownloadsDirectory = Directory(
        '${tempDirectory.path}/real-downloads',
      );
      await realDownloadsDirectory.create();
      final downloadsLink = Link('${tempDirectory.path}/Downloads');
      await downloadsLink.create(realDownloadsDirectory.path);

      expect(
        await resolveDownloadDirectoryPath(Directory(downloadsLink.path)),
        realDownloadsDirectory.path.replaceAll('\\', '/'),
      );
    },
    skip: Platform.isWindows
        ? 'Symlink creation may require elevated Windows privileges.'
        : false,
  );

  test('keeps the provider path when it cannot be resolved', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'localsend-download-path-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final missingDirectory = Directory(
      '${tempDirectory.path}/missing-downloads',
    );

    expect(
      await resolveDownloadDirectoryPath(missingDirectory),
      missingDirectory.path.replaceAll('\\', '/'),
    );
  });
}
