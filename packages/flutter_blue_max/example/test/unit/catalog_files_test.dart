import 'dart:convert';

import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_blue_max_example/gatt/catalog_files.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog files round-trip the services', () {
    final services = [...testDongleServices, ...standardServices];
    expect(jsonEncode(decodeCatalogFile(encodeCatalogFile(services))), jsonEncode(services));
    expect(decodeCatalogFile('{"services": []}'), isEmpty);
  });

  test('foreign files are rejected with a reason', () {
    Matcher rejected(String message) => throwsA(isA<FormatException>().having((e) => e.message, 'message', message));

    expect(() => decodeCatalogFile('not json'), rejected('The file is not JSON.'));
    expect(() => decodeCatalogFile(encodeParserFile(testDongleParsers)), rejected('The file holds no services.'));
    expect(() => decodeCatalogFile('{"services": [1]}'), rejected('Invalid service: 1'));
    expect(() => decodeCatalogFile('{"services": [{"name": "Broken"}]}'), throwsFormatException);
  });
}
