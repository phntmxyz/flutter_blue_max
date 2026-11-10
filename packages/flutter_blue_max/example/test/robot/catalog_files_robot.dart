import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_blue_max_example/gatt/catalog_files.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import 'workbench_robot.dart';

/// Vendor services that no catalog knows, for import files.
final _thermostat = KnownService(Guid('fff0'), 'Thermostat', test: true, [
  KnownCharacteristic(Guid('fff1'), 'Level', properties: {GattProperty.read, GattProperty.notify}),
]);
final _roomThermostat = KnownService(Guid('fff0'), 'Room thermostat', test: true, [
  KnownCharacteristic(Guid('fff1'), 'Level', properties: {GattProperty.read, GattProperty.notify}),
]);
final _lamp = KnownService(Guid('ffe0'), 'Lamp', [KnownCharacteristic(Guid('ffe1'), 'Switch')]);

/// Import, export and reset of the user's own GATT catalog services in the Library tab.
extension CatalogFilesRobot on WorkbenchRobot {
  Future<void> openCatalog() async {
    await tapLabel('Library');
    await tapLabel('GATT catalog');
  }

  Future<void> importServices(List<KnownService> services, {required String confirm}) async {
    logEvent('Pick a catalog file with ${services.map((service) => service.name).join(', ')}');
    files.openContent = encodeCatalogFile(services);
    await tapLabel('Import');
    await tapInDialog(confirm);
  }

  Future<void> importReplacingOwnEntries() async {
    await openCatalog();
    await importServices([_thermostat], confirm: 'Import 1 service');
    spotText('Imported 1 service', exact: true).existsOnce();
    logEvent('Import a renamed thermostat, a new lamp and the unchanged thermostat again');
    files.openContent = encodeCatalogFile([_roomThermostat, _lamp]);
    await tapLabel('Import');
    spot<Dialog>().spotText('FFF0 · 1 characteristic · Replaces your Thermostat', exact: true).existsOnce();
    spot<Dialog>().spotText('FFE0 · 1 characteristic', exact: true).existsOnce();
    await tapInDialog('Import 2 services');
    spotText('Imported 2 services, 1 replaced your own', exact: true).existsOnce();
    expect(controller.catalog.map((service) => service.name), ['Room thermostat', 'Lamp']);
    await importServices([_lamp], confirm: 'Import 1 service');
    spotText('Imported 0 services, 1 was already present', exact: true).existsOnce();
    expect(controller.catalog, hasLength(2));
  }

  Future<void> exportChosenServicesThroughShareSheet() async {
    await openCatalog();
    final export = spot<OutlinedButton>().withChild(spotText('Export', exact: true))..existsOnce();
    expect(export.snapshotWidget().onPressed, isNull, reason: 'Built-in entries are not exported');
    await importServices([_thermostat, _lamp], confirm: 'Import 2 services');
    await tapLabel('Export');
    await tapInDialog('Lamp');
    await tapInDialog('Export 1 service');
    logEvent('Verify that the share sheet received a file with only the chosen service');
    final params = share.shared.single;
    expect(params.fileNameOverrides, [catalogFileName]);
    final content = await tester.runAsync(() => params.files!.single.readAsString());
    expect([for (final service in decodeCatalogFile(content!)) service.name], ['Thermostat']);
    spotText('Exported 1 service', exact: true).existsOnce();
  }

  Future<void> rejectParserFileAsCatalog() async {
    logEvent('Pick a parser file in the GATT catalog');
    files.openContent = encodeParserFile(testDongleParsers);
    await openCatalog();
    await tapLabel('Import');
    spot<Dialog>().doesNotExist();
    spotText('Import failed: The file holds no services.', exact: true).existsOnce();
    expect(controller.catalog, isEmpty);
  }

  Future<void> resetOwnServices() async {
    await openCatalog();
    await importServices([_thermostat], confirm: 'Import 1 service');
    await tapLabel('Reset catalog');
    logEvent('Cancelling keeps the own service');
    await tapInDialog('Cancel');
    expect(controller.catalog, hasLength(1));
    await tapLabel('Reset catalog');
    await tapInDialog('Reset');
    expect(controller.catalog, isEmpty);
    logEvent('Built-in entries stay');
    spotText('FBM Test', exact: true).existsOnce();
  }
}
