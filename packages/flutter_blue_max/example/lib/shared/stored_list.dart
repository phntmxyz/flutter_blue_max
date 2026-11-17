import 'dart:convert';

import 'package:flutter_blue_max_example/shared/json_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A list loaded from the platform's preferences, which are local storage on the web.
/// Entries that no longer decode, e.g. ones written by a newer build, stay in [unreadable]
/// and are written back unchanged by [saveStoredList], so one bad entry never costs the others.
class const StoredList<T>(
  /// The entries that decoded, in stored order.
  final List<T> items, {

  /// The raw entries that did not decode, in stored order.
  final List<Object?> unreadable = const [],

  /// Why the first unreadable entry failed to decode.
  final FormatException? problem,
});

/// Null until the list was saved once.
/// Accepts legacy bare lists and versioned envelopes. Throws [FormatException] for malformed or newer formats.
Future<StoredList<T>?> loadStoredList<T>(String key, T Function(Map<String, dynamic> json) fromJson) async {
  final preferences = await SharedPreferences.getInstance();
  final text = preferences.getString(key);
  if (text == null) {
    return null;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (exception) {
    throw FormatException('The stored value is not JSON: ${exception.message}');
  }
  final List<Object?> entries;
  if (decoded is List) {
    entries = decoded;
  } else if (decoded is Map<String, dynamic>) {
    checkJsonListVersion(decoded, source: 'stored library');
    final items = decoded['items'];
    if (items is! List) {
      throw const FormatException('The stored value holds no item list.');
    }
    entries = items;
  } else {
    throw const FormatException('The stored value is not a list.');
  }
  final items = <T>[];
  final unreadable = <Object?>[];
  FormatException? problem;
  for (final entry in entries) {
    if (entry is! Map<String, dynamic>) {
      unreadable.add(entry);
      problem ??= FormatException('Not an object: $entry');
      continue;
    }
    try {
      items.add(fromJson(entry));
    } on FormatException catch (exception) {
      unreadable.add(entry);
      problem ??= exception;
    }
  }
  return StoredList(items, unreadable: unreadable, problem: problem);
}

/// Writes [items] followed by the [unreadable] entries a previous load kept.
Future<void> saveStoredList(String key, List<Object?> items, {List<Object?> unreadable = const []}) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    key,
    jsonEncode({
      'version': jsonListVersion,
      'items': [...items, ...unreadable],
    }),
  );
}
