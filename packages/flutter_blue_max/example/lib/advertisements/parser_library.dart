import 'dart:convert';

import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_store.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';

/// Owns the saved parser list across Bluetooth sessions; imports skip identical definitions.
class ParserLibrary({required super.onProblem, super.write, super.read = loadParsers})
    extends PersistedLibrary<AdvertisementParser> {
  this
    : super(
        key: parserStoreKey,
        label: 'parsers',
        resetAction: 'Reset parsers',
        resetNoun: 'parsers',
        defaults: testDongleParsers,
      );
  List<AdvertisementParser> get parsers => items;
  Future<void> saveParser(AdvertisementParser parser, {AdvertisementParser? previous}) =>
      save(parser, previous: previous);
  Future<void> removeParser(AdvertisementParser parser) => remove(parser);
  Future<void> resetParsers() => reset();

  Future<int> addParsers(List<AdvertisementParser> parsers) => change((items) {
    final existing = {for (final parser in items) jsonEncode(parser)};
    final added = parsers.where((p) => existing.add(jsonEncode(p))).toList();
    items.addAll(added);
    return added.length;
  });
}
