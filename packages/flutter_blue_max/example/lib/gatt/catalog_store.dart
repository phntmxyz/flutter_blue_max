import 'dart:convert';

import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's own catalog services, stored as JSON in the platform's preferences like the parsers.
const catalogStoreKey = 'gatt_catalog';

Future<List<KnownService>> loadCatalog() async {
  final preferences = await SharedPreferences.getInstance();
  final json = preferences.getString(catalogStoreKey);
  if (json == null) {
    return [];
  }
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw const FormatException('Stored catalog is not a list.');
  }
  return [for (final service in decoded) KnownService.fromJson(service as Map<String, dynamic>)];
}

Future<void> saveCatalog(List<KnownService> services) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(catalogStoreKey, jsonEncode([for (final service in services) service.toJson()]));
}
