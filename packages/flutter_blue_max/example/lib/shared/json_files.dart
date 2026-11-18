import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_max_example/shared/json_format.dart';
import 'package:flutter_blue_max_example/shared/noun.dart';
import 'package:share_plus/share_plus.dart';

const _jsonFiles = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

/// Items are wrapped in an object under [key], so other JSON files are recognised as foreign.
String encodeJsonList(String key, List<Object?> items) =>
    const JsonEncoder.withIndent('  ').convert({'version': jsonListVersion, key: items});

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
  } on FormatException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      FormatException('The file is not JSON: ${exception.message}', exception.source, exception.offset),
      stackTrace,
    );
  }
  if (json is Map<String, dynamic>) {
    checkJsonListVersion(json, source: 'file');
  }
  final items = json is Map<String, dynamic> ? json[key] : null;
  if (items is! List) {
    throw FormatException('The file holds no ${noun.plural}.');
  }
  return [
    for (final item in items)
      if (item is Map<String, dynamic>) fromJson(item) else throw FormatException('Invalid ${noun.singular}: $item'),
  ];
}

/// Lets the user pick a JSON file and returns its text; null when cancelled.
Future<String?> openJsonFile() async {
  final file = await openFile(acceptedTypeGroups: [_jsonFiles]);
  return file == null ? null : await file.readAsString();
}

/// Opens the native share sheet for a phone export.
typedef ShareFile = Future<ShareResult> Function(ShareParams params);

enum ExportOutcome() {
  saved,
  cancelled,
  unconfirmed,
}

/// Saves [json] as [name] through a desktop save dialog, a browser download, or a phone share sheet.
/// [origin] anchors the share sheet on iPad.
Future<ExportOutcome> saveJsonFile(String name, String json, {Rect? origin, ShareFile? shareFile}) async {
  final file = XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: name);
  final phone =
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };
  if (phone) {
    final share = shareFile ?? SharePlus.instance.share;
    final result = await share(ShareParams(files: [file], fileNameOverrides: [name], sharePositionOrigin: origin));
    return switch (result.status) {
      ShareResultStatus.success => ExportOutcome.saved,
      ShareResultStatus.dismissed => ExportOutcome.cancelled,
      ShareResultStatus.unavailable => ExportOutcome.unconfirmed,
    };
  }
  if (kIsWeb) {
    await file.saveTo(name);
    return ExportOutcome.saved;
  }
  final location = await getSaveLocation(acceptedTypeGroups: [_jsonFiles], suggestedName: name);
  if (location == null) {
    return ExportOutcome.cancelled;
  }
  await file.saveTo(location.path);
  return ExportOutcome.saved;
}
