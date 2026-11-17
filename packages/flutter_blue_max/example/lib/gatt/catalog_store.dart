import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// The user's own catalog services, stored as JSON in the platform's preferences like the parsers.
const catalogStoreKey = 'gatt_catalog';

/// Null until the catalog was saved once; unreadable entries are retained in [StoredList.unreadable].
/// Throws a [FormatException] when the stored value is invalid JSON or not a list.
Future<StoredList<KnownService>?> loadCatalog() => loadStoredList(catalogStoreKey, KnownService.fromJson);
