import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/gatt/catalog_import_result.dart';
import 'package:flutter_blue_max_example/gatt/catalog_store.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// Owns the user's saved catalog independently of Bluetooth; imports replace by UUID.
class GattCatalogLibrary({
  required void Function(LibraryProblem) onProblem,
  Future<void> Function(String key, List<Object?> items, {List<Object?> unreadable}) write = saveStoredList,
  Future<StoredList<KnownService>?> Function() read = loadCatalog,
}) extends ChangeNotifier {
  this {
    _store.addListener(notifyListeners);
  }

  final _store = PersistedLibrary<KnownService>(
    key: catalogStoreKey,
    label: 'GATT catalog',
    resetAction: 'Reset catalog',
    resetNoun: 'catalog',
    read: read,
    write: write,
    onProblem: onProblem,
  );

  List<KnownService> get catalog => _store.items;
  Future<void> load() => _store.load();
  Future<void> save(KnownService service, {KnownService? previous}) => _store.change((items) {
    final index = previous == null ? -1 : items.indexOf(previous);
    if (previous != null && index < 0) {
      throw const CatalogConflict('This catalog entry changed while you were editing it. Reopen it and try again.');
    }
    if (items.any((s) => !identical(s, previous) && s.uuid == service.uuid)) {
      throw const CatalogConflict('Your catalog already has a service with this UUID.');
    }
    if (index < 0) {
      items.add(service);
    } else {
      items[index] = service;
    }
  });
  Future<void> remove(KnownService service) => _store.remove(service);
  Future<void> reset() => _store.reset();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  /// The entries that the proposed import would replace after initial storage has loaded.
  Future<Map<Guid, KnownService>> previewReplacements(List<KnownService> services) async {
    await load();
    final existing = {for (final own in catalog) own.uuid: own};
    return Map.unmodifiable({
      for (final service in services)
        if (existing[service.uuid] case final own? when !_sameService(own, service)) service.uuid: own,
    });
  }

  /// Reports the in-memory counts and whether the resulting catalog was saved.
  /// Replacements are permitted only when the existing entry matches the confirmed preview.
  Future<LibraryChange<CatalogImportResult>> addCatalogServices(
    List<KnownService> services, {
    Map<Guid, KnownService> confirmedReplacements = const {},
  }) => _store.change((items) {
    final existing = {for (final own in items) own.uuid: own};
    for (final service in services) {
      final own = existing[service.uuid];
      if (own != null && !_sameService(own, service) && !_sameService(own, confirmedReplacements[service.uuid])) {
        throw const CatalogConflict(
          'The catalog changed after the preview. Reopen the import and check the replacements.',
        );
      }
    }
    var added = 0;
    var replaced = 0;
    var present = 0;
    for (final service in services) {
      final own = items.where((s) => s.uuid == service.uuid).firstOrNull;
      if (own == null) {
        items.add(service);
        added++;
      } else if (_sameService(own, service)) {
        present++;
      } else {
        items[items.indexOf(own)] = service;
        replaced++;
      }
    }
    return CatalogImportResult(added: added, replaced: replaced, present: present);
  });
}

bool _sameService(KnownService first, KnownService? second) =>
    second != null && jsonEncode(first) == jsonEncode(second);

/// An edit or import would replace catalog content the user has not confirmed.
class const CatalogConflict(final String message) implements Exception;
