import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:share_plus/share_plus.dart';

const parserFileName = 'blue_max_parsers.json';

const _jsonFiles = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

/// Parsers are wrapped in an object, so other JSON files are recognised as foreign.
String encodeParserFile(List<AdvertisementParser> parsers) =>
    const JsonEncoder.withIndent('  ').convert({'parsers': parsers});

/// Throws a [FormatException] for files that do not hold parsers.
List<AdvertisementParser> decodeParserFile(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('The file is not JSON.');
  }
  final parsers = json is Map<String, dynamic> ? json['parsers'] : null;
  if (parsers is! List) {
    throw const FormatException('The file holds no parsers.');
  }
  return [
    for (final parser in parsers)
      if (parser is Map<String, dynamic>)
        AdvertisementParser.fromJson(parser)
      else
        throw FormatException('Invalid parser: $parser'),
  ];
}

/// Lets the user pick a parser file; null when cancelled.
Future<List<AdvertisementParser>?> openParserFile() async {
  final file = await openFile(acceptedTypeGroups: [_jsonFiles]);
  return file == null ? null : decodeParserFile(await file.readAsString());
}

/// Saves [parsers] where the user chooses: a save dialog on desktop, a download on the web, and the share sheet on
/// phones, whose file pickers cannot save. [origin] anchors the share sheet on iPad.
/// Returns false when the user cancelled.
Future<bool> saveParserFile(List<AdvertisementParser> parsers, {Rect? origin}) async {
  final file = XFile.fromData(
    utf8.encode(encodeParserFile(parsers)),
    mimeType: 'application/json',
    name: parserFileName,
  );
  final phone =
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };
  if (phone) {
    final result = await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [parserFileName], sharePositionOrigin: origin),
    );
    return result.status != ShareResultStatus.dismissed;
  }
  final location = await getSaveLocation(acceptedTypeGroups: [_jsonFiles], suggestedName: parserFileName);
  if (location == null) {
    return false;
  }
  await file.saveTo(location.path);
  return true;
}
