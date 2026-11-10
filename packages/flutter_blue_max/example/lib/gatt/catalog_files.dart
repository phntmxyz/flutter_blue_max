import 'dart:ui';

import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_blue_max_example/shared/json_files.dart';
import 'package:flutter_blue_max_example/shared/noun.dart';

const catalogFileName = 'blue_max_gatt_catalog.json';
const Noun serviceNoun = ('service', 'services');
const _key = 'services';

String encodeCatalogFile(List<KnownService> services) => encodeJsonList(_key, services);

/// Throws a [FormatException] for files that do not hold catalog services.
List<KnownService> decodeCatalogFile(String text) =>
    decodeJsonList(text, key: _key, noun: serviceNoun, fromJson: KnownService.fromJson);

/// Lets the user pick a catalog file; null when cancelled.
Future<List<KnownService>?> openCatalogFile() async {
  final text = await openJsonFile();
  return text == null ? null : decodeCatalogFile(text);
}

/// Returns false when the user cancelled; see [saveJsonFile].
Future<bool> saveCatalogFile(List<KnownService> services, {Rect? origin}) =>
    saveJsonFile(catalogFileName, encodeCatalogFile(services), origin: origin);
