import "dart:ui";

import "package:flutter_blue_max_example/advertisements/advertisement_parser.dart";
import "package:flutter_blue_max_example/shared/json_files.dart";
import "package:flutter_blue_max_example/shared/noun.dart";

const parserFileName = "blue_max_parsers.json";
const Noun parserNoun = Noun(singular: "parser", plural: "parsers");
const _key = "parsers";

String encodeParserFile(List<AdvertisementParser> parsers) => encodeJsonList(_key, parsers);

/// Throws a [FormatException] for files that do not hold parsers.
List<AdvertisementParser> decodeParserFile(String text) =>
    decodeJsonList(text, key: _key, noun: parserNoun, fromJson: AdvertisementParser.fromJson);

/// Lets the user pick a parser file; null when cancelled.
Future<List<AdvertisementParser>?> openParserFile() async {
  final text = await openJsonFile();
  return text == null ? null : decodeParserFile(text);
}

/// Exports the selected entries using [saveJsonFile].
Future<ExportOutcome> saveParserFile(List<AdvertisementParser> parsers, {Rect? origin, ShareFile? shareFile}) =>
    saveJsonFile(parserFileName, encodeParserFile(parsers), origin: origin, shareFile: shareFile);
