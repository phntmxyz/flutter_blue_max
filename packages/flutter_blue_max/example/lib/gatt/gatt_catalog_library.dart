import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final _store = PersistedLibrary<KnownService>(
    key: catalogStoreKey,
    label: 'GATT catalog',
    resetAction: 'Reset catalog',
    resetNoun: 'catalog',
    read: read,
    write: write,
    onProblem: onProblem,
  );

  this {
    _store.addListener(notifyListeners);
  }

  List<KnownService> get catalog => _store.items;
  Future<void> load() => _store.load();
  Future<void> save(KnownService service, {KnownService? previous}) => _store.save(service, previous: previous);
  Future<void> remove(KnownService service) => _store.remove(service);
  Future<void> reset() => _store.reset();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  KnownService? catalogServiceReplacedBy(KnownService service) {
    final own = catalog.where((s) => s.uuid == service.uuid).firstOrNull;
    return own == null || jsonEncode(own) == jsonEncode(service) ? null : own;
  }

  /// Reports the in-memory counts and whether the resulting catalog was saved.
  Future<LibraryChange<CatalogImportResult>> addCatalogServices(List<KnownService> services) => _store.change((items) {
    var added = 0;
    var replaced = 0;
    var present = 0;
    for (final service in services) {
      final own = items.where((s) => s.uuid == service.uuid).firstOrNull;
      if (own == null) {
        items.add(service);
        added++;
      } else if (jsonEncode(own) == jsonEncode(service)) {
        present++;
      } else {
        items[items.indexOf(own)] = service;
        replaced++;
      }
    }
    return CatalogImportResult(added: added, replaced: replaced, present: present);
  });
}
