import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_max_example/shared/noun.dart';
import 'package:share_plus/share_plus.dart';

const _jsonFiles = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

/// Items are wrapped in an object under [key], so other JSON files are recognised as foreign.
String encodeJsonList(String key, List<Object?> items) => const JsonEncoder.withIndent('  ').convert({key: items});

/// Reads what [encodeJsonList] wrote under [key].
/// Throws a [FormatException], worded with [noun], for files that hold something else.
List<T> decodeJsonList<T>(
  String text, {
  required String key,
  required Noun noun,
  required T Function(Map<String, dynamic> json) fromJson,
}) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('The file is not JSON.');
  }
  final items = json is Map<String, dynamic> ? json[key] : null;
  if (items is! List) {
    throw FormatException('The file holds no ${noun.$2}.');
  }
  return [
    for (final item in items)
      if (item is Map<String, dynamic>) fromJson(item) else throw FormatException('Invalid ${noun.$1}: $item'),
  ];
}

/// Lets the user pick a JSON file and returns its text; null when cancelled.
Future<String?> openJsonFile() async {
  final file = await openFile(acceptedTypeGroups: [_jsonFiles]);
  return file == null ? null : await file.readAsString();
}

/// Saves [json] as [name] where the user chooses: a save dialog on desktop, a download on the web, and the share
/// sheet on phones, whose file pickers cannot save. [origin] anchors the share sheet on iPad.
/// Returns false when the user cancelled.
Future<bool> saveJsonFile(String name, String json, {Rect? origin}) async {
  final file = XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: name);
  final phone =
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };
  if (phone) {
    final result = await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [name], sharePositionOrigin: origin),
    );
    return result.status != ShareResultStatus.dismissed;
  }
  final location = await getSaveLocation(acceptedTypeGroups: [_jsonFiles], suggestedName: name);
  if (location == null) {
    return false;
  }
  await file.saveTo(location.path);
  return true;
}
