import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// The user's own catalog services, stored as JSON in the platform's preferences like the parsers.
const catalogStoreKey = 'gatt_catalog';

/// Null until the catalog was saved once.
Future<StoredList<KnownService>?> loadCatalog() => loadStoredList(catalogStoreKey, KnownService.fromJson);

/// Keeps the [unreadable] entries of the last load, so saving never drops them.
Future<void> saveCatalog(List<KnownService> services, {List<Object?> unreadable = const []}) =>
    saveStoredList(catalogStoreKey, services, unreadable: unreadable);
