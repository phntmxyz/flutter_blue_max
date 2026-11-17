import 'dart:convert';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_blue_max_example/gatt/catalog_files.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog files round-trip the services', () {
    final services = [...testDongleServices, ...standardServices];
    expect(jsonEncode(decodeCatalogFile(encodeCatalogFile(services))), jsonEncode(services));
    expect(decodeCatalogFile('{"services": []}'), isEmpty);
  });

  test('a file with duplicate service UUIDs is rejected before it can overwrite entries', () {
    final first = KnownService(Guid('fff0'), 'First', []);
    final second = KnownService(Guid('fff0'), 'Second', []);
    expect(() => decodeCatalogFile(encodeCatalogFile([first, second])), throwsFormatException);
    expect(() => decodeCatalogFile(encodeCatalogFile([first, first])), throwsFormatException);
  });

  test('foreign files are rejected with a reason', () {
    Matcher rejected(String message) => throwsA(isA<FormatException>().having((e) => e.message, 'message', message));

    expect(
      () => decodeCatalogFile('not json'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', startsWith('The file is not JSON:'))),
    );
    expect(() => decodeCatalogFile(encodeParserFile(testDongleParsers)), rejected('The file holds no services.'));
    expect(() => decodeCatalogFile('{"services": [1]}'), rejected('Invalid service: 1'));
    expect(() => decodeCatalogFile('{"services": [{"name": "Broken"}]}'), throwsFormatException);
  });
}
