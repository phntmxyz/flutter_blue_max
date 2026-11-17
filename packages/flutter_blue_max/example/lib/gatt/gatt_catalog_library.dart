import 'dart:convert';

import 'package:flutter_blue_max_example/gatt/catalog_import_result.dart';
import 'package:flutter_blue_max_example/gatt/catalog_store.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';

/// Owns the user's saved catalog independently of Bluetooth; imports replace by UUID.
class GattCatalogLibrary({required super.onProblem, super.write, super.read = loadCatalog})
    extends PersistedLibrary<KnownService> {
  this : super(key: catalogStoreKey, label: 'GATT catalog', resetAction: 'Reset catalog', resetNoun: 'catalog');
  List<KnownService> get catalog => items;
  Future<void> saveCatalogService(KnownService service, {KnownService? previous}) => save(service, previous: previous);
  Future<void> removeCatalogService(KnownService service) => remove(service);
  Future<void> resetCatalog() => reset();

  KnownService? catalogServiceReplacedBy(KnownService service) {
    final own = items.where((s) => s.uuid == service.uuid).firstOrNull;
    return own == null || jsonEncode(own) == jsonEncode(service) ? null : own;
  }

  Future<CatalogImportResult> addCatalogServices(List<KnownService> services) => change((items) {
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
