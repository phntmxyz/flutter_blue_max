import 'dart:async';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_library.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog_library.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Edit() {
  save,
  remove,
  reset,
}

void main() {
  for (final edit in _Edit.values) {
    test('$edit waits for the stored list before changing or persisting it', () async {
      final loading = Completer<StoredList<int>?>();
      final writes = <List<Object?>>[];
      final problems = <LibraryProblem>[];
      final library = PersistedLibrary<int>(
        key: 'test',
        label: 'test entries',
        resetAction: 'Reset',
        resetNoun: 'entries',
        defaults: [9],
        read: () => loading.future,
        onProblem: problems.add,
        write: (_, items, {unreadable = const []}) async {
          writes.add(items);
        },
      );
      addTearDown(library.dispose);
      final pending = switch (edit) {
        _Edit.save => library.save(3),
        _Edit.remove => library.remove(1),
        _Edit.reset => library.reset(),
      };
      await Future<void>.delayed(Duration.zero);
      expect(writes, isEmpty);
      loading.complete(const StoredList([1, 2]));
      await pending;
      final expected = switch (edit) {
        _Edit.save => [1, 2, 3],
        _Edit.remove => [2],
        _Edit.reset => [9],
      };
      expect(library.items, expected);
      expect(writes, [expected]);
      expect(problems, isEmpty);
    });
  }

  test('parser import waits for loading and preserves earlier stored parsers', () async {
    final loading = Completer<StoredList<AdvertisementParser>?>();
    final writes = <List<Object?>>[];
    final library = ParserLibrary(
      read: () => loading.future,
      onProblem: (_) => fail('Unexpected library problem'),
      write: (_, items, {unreadable = const []}) async {
        writes.add(items);
      },
    );
    addTearDown(library.dispose);
    final pending = library.addParsers([testDongleParsers.last]);
    await Future<void>.delayed(Duration.zero);
    expect(writes, isEmpty);
    loading.complete(StoredList([testDongleParsers.first]));
    expect(await pending, 1);
    expect(library.items, [testDongleParsers.first, testDongleParsers.last]);
    expect(writes.single, library.items);
  });

  test('catalog import waits for loading and replaces in place by UUID', () async {
    final loading = Completer<StoredList<KnownService>?>();
    final original = KnownService(Guid('fff0'), 'Original', []);
    final replacement = KnownService(Guid('fff0'), 'Replacement', []);
    final retained = KnownService(Guid('fff1'), 'Retained', []);
    final writes = <List<Object?>>[];
    final library = GattCatalogLibrary(
      read: () => loading.future,
      onProblem: (_) => fail('Unexpected library problem'),
      write: (_, items, {unreadable = const []}) async {
        writes.add(items);
      },
    );
    addTearDown(library.dispose);
    final pending = library.addCatalogServices([replacement]);
    await Future<void>.delayed(Duration.zero);
    expect(writes, isEmpty);
    loading.complete(StoredList([original, retained]));
    final result = await pending;
    expect([result.added, result.replaced, result.present], [0, 1, 0]);
    expect(library.items, [replacement, retained]);
    expect(writes.single, library.items);
  });
}
