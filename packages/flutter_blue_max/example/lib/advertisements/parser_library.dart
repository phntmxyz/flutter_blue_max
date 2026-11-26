import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_store.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// Owns the saved parser list across Bluetooth sessions; imports skip identical definitions.
class ParserLibrary({
  required void Function(LibraryProblem) onProblem,
  Future<void> Function(String key, List<Object?> items, {List<Object?> unreadable}) write = saveStoredList,
  Future<StoredList<AdvertisementParser>?> Function() read = loadParsers,
}) extends ChangeNotifier {
  this {
    _store.addListener(notifyListeners);
  }

  final _store = PersistedLibrary<AdvertisementParser>(
    key: parserStoreKey,
    label: 'parsers',
    resetAction: 'Reset parsers',
    resetNoun: 'parsers',
    defaults: testDongleParsers,
    read: read,
    write: write,
    onProblem: onProblem,
  );

  List<AdvertisementParser> get parsers => _store.items;
  Future<void> load() => _store.load();
  Future<void> save(AdvertisementParser parser, {AdvertisementParser? previous}) =>
      _store.save(parser, previous: previous);
  Future<void> remove(AdvertisementParser parser) => _store.remove(parser);
  Future<void> reset() => _store.reset();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  /// Reports the number of new entries and whether the resulting list was saved.
  Future<LibraryChange<int>> addParsers(List<AdvertisementParser> parsers) => _store.change((items) {
    final existing = {for (final parser in items) jsonEncode(parser)};
    final added = parsers.where((p) => existing.add(jsonEncode(p))).toList();
    items.addAll(added);
    return added.length;
  });
}
