import 'dart:convert';

import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsers are stored as JSON in the platform's preferences, which is local storage on the web.
const parserStoreKey = 'advertisement_parsers';

/// Null until parsers were saved once, so first launches can start with examples.
Future<List<AdvertisementParser>?> loadParsers() async {
  final preferences = await SharedPreferences.getInstance();
  final json = preferences.getString(parserStoreKey);
  if (json == null) {
    return null;
  }
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw const FormatException('Stored parsers are not a list.');
  }
  return [for (final parser in decoded) AdvertisementParser.fromJson(parser as Map<String, dynamic>)];
}

Future<void> saveParsers(List<AdvertisementParser> parsers) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(parserStoreKey, jsonEncode([for (final parser in parsers) parser.toJson()]));
}
