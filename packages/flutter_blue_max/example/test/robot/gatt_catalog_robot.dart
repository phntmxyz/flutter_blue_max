import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/gatt/catalog_panel.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import '../fakes/fake_bluetooth_platform.dart';
import 'workbench_robot.dart';

Guid _fbm(String shortId) => Guid('7e57$shortId-85d8-4594-ac4f-b32fc01e9a49');

final _testService = _fbm('0001');
final _dynamicService = _fbm('0002');
final _echo = _fbm('0101');
final _status = _fbm('0105');
final _unlisted = _fbm('0199');
final _dynamicValue = _fbm('0301');

/// The GATT catalog and User Descriptions, checked against a partial FBM test dongle database.
extension GattCatalogRobot on WorkbenchRobot {
  Future<void> discoverPartialTestDongle() async {
    logEvent('Serve a test service with a wrong Status, an unlisted characteristic and most others missing');
    platform.extraServices[_testService] = {
      _echo: FakeBluetoothPlatform.properties(read: true, write: true, writeWithoutResponse: true, notify: true),
      _status: FakeBluetoothPlatform.properties(read: true),
      _unlisted: FakeBluetoothPlatform.properties(read: true),
    };
    platform.extraServices[_dynamicService] = {_dynamicValue: FakeBluetoothPlatform.properties(read: true)};
    platform.descriptorValues[_echo] = utf8.encode('Echo: writes are notified back');
    platform.descriptorValues[_unlisted] = utf8.encode('Firmware extra');
    await inspectPeripheral();
    logEvent('Discovery reads every User Description once');
    expect(platform.descriptorReads.map((read) => read.characteristicUuid), [_echo, _status, _unlisted, _dynamicValue]);
  }

  void expectNamedServices() {
    spotText('Battery', exact: true).existsOnce();
    spotText('FBM Test', exact: true).existsOnce();
    spotText('FBM Dynamic', exact: true).existsOnce();
    spotText(
      'Missing: Echo Indicate, Long, Throughput, Control, Encrypted, Authenticated, Descriptors, L2CAP Info, '
      'Counter, ATT Error, L2CAP PSM',
      exact: true,
    ).existsOnce();
    spotText('Unexpected properties: Status', exact: true).existsOnce();
    spotIcon(Icons.error_outline_rounded).existsOnce();
    spotIcon(Icons.check_circle_rounded).existsOnce();
  }

  Future<void> inspectTestCharacteristics() async {
    await tapLabel('FBM Test');
    logEvent('A matching characteristic is labelled as test, a deviating one shows what was expected');
    spotText('Test · Echo', exact: true).existsOnce();
    spotText('Echo: writes are notified back', exact: true).existsOnce();
    spotText('Status', exact: true).existsOnce();
    spotText('Expected Read · Notify', exact: true).existsOnce();
    logEvent('A characteristic outside the catalog is named by its User Description');
    spotText('Firmware extra', exact: true).existsOnce();
    spotText(_unlisted.str.toUpperCase(), exact: true).existsOnce();
    await tapLabel('FBM Dynamic');
    spotText('Test · Dynamic Value', exact: true).existsOnce();
  }

  Future<void> addDiscoveredServiceToCatalog() async {
    logEvent('Discover a vendor service that no catalog knows, with User Descriptions');
    final thermostat = Guid('fff0');
    final level = Guid('fff1');
    final setpoint = Guid('fff2');
    platform.extraServices[thermostat] = {
      level: FakeBluetoothPlatform.properties(read: true, notify: true),
      setpoint: FakeBluetoothPlatform.properties(write: true),
    };
    platform.descriptorValues[level] = utf8.encode('Level');
    platform.descriptorValues[setpoint] = utf8.encode('Setpoint');
    await inspectPeripheral();
    await tapLabel('FFF0');
    await tapLabel('Add to catalog');
    logEvent('The editor starts from the discovered characteristics');
    expect(_field('Service UUID').snapshotWidget().controller!.text, 'fff0');
    spotText('Replaces the built-in').doesNotExist();
    final names = spot<TextField>().withChild(spotText('Characteristic name', exact: true));
    expect([for (final field in names.snapshot().discoveredWidgets) field.controller!.text], ['Level', 'Setpoint']);
    await _enter('Service name', 'Thermostat');
    await tapLabel('Save entry');
    expect(controller.catalog.single.name, 'Thermostat');
    expect(controller.catalog.single.test, isTrue);
    logEvent('The explorer now names and checks the service');
    spotText('Thermostat', exact: true).existsOnce();
    spotText('Test · Level', exact: true).existsOnce();
    spotText('Test · Setpoint', exact: true).existsOnce();
    spotText('Edit catalog entry', exact: true).existsOnce();
  }

  Future<void> removeOwnCatalogService() async {
    await tapLabel('Library');
    await tapLabel('GATT catalog');
    spotText('FBM Test', exact: true).existsOnce();
    spotText('Thermostat', exact: true).existsOnce();
    await tapLabel('Thermostat');
    await tapLabel('Remove');
    expect(controller.catalog, isEmpty);
    logEvent('Scroll back to the own services');
    final list = find.descendant(of: find.byType(CatalogPanel), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.textContaining('None yet.'), -300, scrollable: list);
    await idle();
    spotText('None yet. Add a service here or from a discovered service in the GATT explorer.').existsOnce();
  }

  WidgetSelector<TextField> _field(String label) => spot<TextField>().withChild(spotText(label, exact: true));

  Future<void> _enter(String label, String text) async {
    logEvent('Enter "$text" into "$label"');
    final field = _field(label)..existsOnce();
    await tester.ensureVisible(find.widgetWithText(TextField, label));
    await idle();
    await act.enterText(field, text);
    await idle();
  }
}
