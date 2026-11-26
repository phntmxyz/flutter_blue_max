import "dart:convert";

import "package:flutter_blue_max_example/advertisements/parser_examples.dart";
import "package:flutter_blue_max_example/advertisements/parser_files.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parser files round-trip the parsers", () {
    expect(jsonEncode(decodeParserFile(encodeParserFile(testDongleParsers))), jsonEncode(testDongleParsers));
    expect(decodeParserFile('{"parsers": []}'), isEmpty);
  });

  test("malformed JSON retains the decoder reason, source and position", () {
    const text = '{"parsers": [\n?]}';
    final FormatException original;
    try {
      jsonDecode(text);
      fail("Expected the malformed fixture to fail JSON decoding");
    } on FormatException catch (exception) {
      original = exception;
    }
    expect(
      () => decodeParserFile(text),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, "reason", contains(original.message))
            .having((e) => e.source, "source", text)
            .having((e) => e.offset, "offset", original.offset),
      ),
    );
  });

  test("exports declare their version and future file versions are rejected", () {
    final encoded = jsonDecode(encodeParserFile(testDongleParsers)) as Map<String, dynamic>;
    expect(encoded["version"], 1);
    expect(
      () => decodeParserFile('{"version": 2, "parsers": []}'),
      throwsA(isA<FormatException>().having((e) => e.message, "message", contains("newer format"))),
    );
    expect(() => decodeParserFile('{"version": "1", "parsers": []}'), throwsFormatException);
    expect(decodeParserFile('{"parsers": []}'), isEmpty);
  });

  test("foreign files are rejected with a reason", () {
    Matcher rejected(String message) => throwsA(isA<FormatException>().having((e) => e.message, "message", message));

    expect(
      () => decodeParserFile("not json"),
      throwsA(isA<FormatException>().having((e) => e.message, "message", startsWith("The file is not JSON:"))),
    );
    expect(() => decodeParserFile("[]"), rejected("The file holds no parsers."));
    expect(() => decodeParserFile('{"services": []}'), rejected("The file holds no parsers."));
    expect(() => decodeParserFile('{"parsers": [1]}'), rejected("Invalid parser: 1"));
    expect(() => decodeParserFile('{"parsers": [{"name": "Broken"}]}'), throwsFormatException);
  });
}
