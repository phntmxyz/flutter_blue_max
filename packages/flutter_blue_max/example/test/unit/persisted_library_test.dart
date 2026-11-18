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
      loading.complete(StoredList([1, 2]));
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

  test('storage read snapshots freeze decoded and unreadable entries', () {
    final items = [1];
    final unreadable = <Object?>['legacy'];
    final result = StoredList(items, unreadable: unreadable);
    items.clear();
    unreadable.clear();
    expect(result.items, [1]);
    expect(result.unreadable, ['legacy']);
    expect(result.items.clear, throwsUnsupportedError);
    expect(result.unreadable.clear, throwsUnsupportedError);
  });

  test('parser import distinguishes an in-memory edit from a successful write', () async {
    final problems = <LibraryProblem>[];
    final library = ParserLibrary(
      onProblem: problems.add,
      read: () => Future<StoredList<AdvertisementParser>?>.value(),
      write: (_, _, {unreadable = const []}) => Future<void>.error(StateError('Disk full')),
    );
    addTearDown(library.dispose);
    const parser = AdvertisementParser(name: 'Own', source: AdvertisementSource.manufacturer, fields: []);
    final result = await library.addParsers([parser]);
    expect(result.saved, isFalse);
    expect(result.value, 1);
    expect(library.parsers.last, parser);
    expect(problems.single.error, isA<StateError>());
    expect(problems.single.stackTrace, isNotNull);
  });

  test('catalog import does not save over an unreadable envelope', () async {
    final problems = <LibraryProblem>[];
    final library = GattCatalogLibrary(
      onProblem: problems.add,
      read: () => Future<StoredList<KnownService>?>.error(const FormatException('Newer envelope')),
      write: (_, _, {unreadable = const []}) => fail('The protected envelope must stay unchanged'),
    );
    addTearDown(library.dispose);
    final result = await library.addCatalogServices([KnownService(Guid('fff0'), 'Own', [])]);
    expect(result.saved, isFalse);
    expect(result.value.added, 1);
    expect(problems.last.message, contains('changes are not saved'));
  });

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
    final result = await pending;
    expect(result.saved, isTrue);
    expect(result.value, 1);
    expect(library.parsers, [testDongleParsers.first, testDongleParsers.last]);
    expect(writes.single, library.parsers);
  });

  test('catalog save checks for duplicates after loading', () async {
    final loading = Completer<StoredList<KnownService>?>();
    final original = KnownService(Guid('fff0'), 'Original', []);
    final duplicate = KnownService(Guid('fff0'), 'Duplicate', []);
    final library = GattCatalogLibrary(
      read: () => loading.future,
      onProblem: (_) => fail('Unexpected library problem'),
      write: (_, _, {unreadable = const []}) => fail('Do not write the duplicate'),
    );
    addTearDown(library.dispose);
    final rejected = expectLater(library.save(duplicate), throwsA(isA<CatalogConflict>()));
    loading.complete(StoredList([original]));
    await rejected;
    expect(library.catalog, [original]);
  });

  test('catalog replaces only the entry that was confirmed in the preview', () async {
    final original = KnownService(Guid('fff0'), 'Original', []);
    final updated = KnownService(Guid('fff0'), 'Changed after preview', []);
    final replacement = KnownService(Guid('fff0'), 'Replacement', []);
    final newEntry = KnownService(Guid('fff1'), 'New entry', []);
    final writes = <List<Object?>>[];
    final library = GattCatalogLibrary(
      read: () => Future.value(StoredList([original])),
      onProblem: (_) => fail('Unexpected library problem'),
      write: (_, items, {unreadable = const []}) async {
        writes.add(items);
      },
    );
    addTearDown(library.dispose);
    final imports = [newEntry, replacement];
    final preview = await library.previewReplacements(imports);
    await library.save(updated, previous: original);

    await expectLater(
      library.addCatalogServices(imports, confirmedReplacements: preview),
      throwsA(isA<CatalogConflict>()),
    );
    expect(library.catalog, [updated]);
    expect(writes, [
      [updated],
    ]);
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
    final pendingPreview = library.previewReplacements([replacement]);
    await Future<void>.delayed(Duration.zero);
    expect(writes, isEmpty);
    loading.complete(StoredList([original, retained]));
    final confirmed = await pendingPreview;
    expect(confirmed, {original.uuid: original});
    final result = await library.addCatalogServices([replacement], confirmedReplacements: confirmed);
    expect(result.saved, isTrue);
    expect([result.value.added, result.value.replaced, result.value.present], [0, 1, 0]);
    expect(library.catalog, [replacement, retained]);
    expect(writes.single, library.catalog);
  });
}
