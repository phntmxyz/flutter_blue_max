import 'dart:convert';

import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parser files round-trip the parsers', () {
    expect(jsonEncode(decodeParserFile(encodeParserFile(testDongleParsers))), jsonEncode(testDongleParsers));
    expect(decodeParserFile('{"parsers": []}'), isEmpty);
  });

  test('foreign files are rejected with a reason', () {
    Matcher rejected(String message) => throwsA(isA<FormatException>().having((e) => e.message, 'message', message));

    expect(() => decodeParserFile('not json'), rejected('The file is not JSON.'));
    expect(() => decodeParserFile('[]'), rejected('The file holds no parsers.'));
    expect(() => decodeParserFile('{"services": []}'), rejected('The file holds no parsers.'));
    expect(() => decodeParserFile('{"parsers": [1]}'), rejected('Invalid parser: 1'));
    expect(() => decodeParserFile('{"parsers": [{"name": "Broken"}]}'), throwsFormatException);
  });
}
