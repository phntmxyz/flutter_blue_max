@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_blue_max_example/shared/json_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A save-dialog call fails: web exports must download directly.
  FileSelectorPlatform.instance = _NoSaveDialog();

  test('saveJsonFile on the web returns true and clicks a download anchor named after the file', () async {
    final clicked = <web.HTMLAnchorElement>[];
    final listener = ((web.Event event) {
      final target = event.target;
      if (target != null && target.isA<web.HTMLAnchorElement>()) {
        clicked.add(target as web.HTMLAnchorElement);
        event.preventDefault();
      }
    }).toJS;
    web.document.addEventListener('click', listener, true.toJS);
    addTearDown(() => web.document.removeEventListener('click', listener, true.toJS));

    final saved = await saveJsonFile('probe-parsers.json', encodeJsonList('parsers', const []));

    expect(saved, ExportOutcome.saved);
    expect(clicked, hasLength(1));
    expect(clicked.single.download, 'probe-parsers.json');
    expect(clicked.single.href, startsWith('blob:'));
  });
}

final class _NoSaveDialog() extends FileSelectorPlatform;
