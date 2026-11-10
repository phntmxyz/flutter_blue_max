import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import 'workbench_robot.dart';

/// Climate frames of an invented vendor: frame type 0x10, then the temperature as int16 BE in 0.005 °C.
/// The company identifier is unassigned, so the bundled test dongle parsers do not read these frames.
const _vendorId = 0xfffe;
const _warm = [0x10, 0x0f, 0xa0];
const _warmer = [0x10, 0x13, 0x88];
const _otherFrame = [0x11, 0x00, 0x00];

/// A sensor frame of vendor service data: frame type and counter, then records with a 2-byte type and a length,
/// here only illuminance (0x0002) with 65 lx.
final _sensorService = Guid('fff0');
const _sensorLight = [0x10, 0x5a, 0x02, 0x00, 0x03, 0x41, 0x00, 0x00];

/// Parsers and history filters, driven through the device inspector.
extension AdvertisementRobot on WorkbenchRobot {
  Future<void> scanForSensor() async {
    await tapLabel('Start scan');
    logEvent('Receive a sensor advertisement with manufacturer data');
    platform.advertise(manufacturerData: {_vendorId: _warm});
    await idle();
    await tapLabel('Stop scan');
    await selectPeripheral();
    await tapLabel('Advertisement');
  }

  Future<void> addTemperatureParser() async {
    await tapLabel('Add parser');
    logEvent('Verify that the source is prefilled from the latest advertisement');
    expect(_field('Company ID (hex)').snapshotWidget().controller!.text, '0xFFFE');
    await _enter('Parser name', 'Climate');
    await _enter('Bytes (hex)', '10');
    await _enter('Field name', 'Temperature');
    await _enter('Offset', '1');
    await tapLabel('uint8');
    await tapLabel('int16 BE');
    await _enter('Scale', '0.005');
    await _enter('Unit', '°C');
    logEvent('Verify the live preview against the sample bytes');
    spotText('Climate · Temperature: 20.000 °C', exact: true).existsOnce();
    await tapLabel('Save parser');
    spotText('Climate · Temperature: 20.000 °C').existsOnce();
    spotText('Manufacturer 0xfffe · match 10 at 0 · 1 field · All devices', exact: true).existsOnce();
    logEvent('Verify that unrelated global parsers do not crowd the device');
    spotText('FBM status').doesNotExist();
  }

  Future<void> scanForRecordSensor() async {
    await tapLabel('Start scan');
    logEvent('Receive a sensor advertisement with record-based service data');
    platform.advertise(serviceData: {_sensorService: _sensorLight});
    await idle();
    await tapLabel('Stop scan');
    await selectPeripheral();
    await tapLabel('Advertisement');
  }

  Future<void> addRecordParser() async {
    await tapLabel('Add parser');
    logEvent('Verify that the service data source is prefilled from the latest advertisement');
    expect(_field('Service UUID').snapshotWidget().controller!.text, 'fff0');
    await _enter('Parser name', 'Sensor');
    await tapLabel('Records');
    await _enter('Records start at', '2');
    await tapLabel('1 byte');
    await tapLabel('2 bytes LE');
    await _enter('Record type (hex)', '0002');
    await _enter('Field name', 'Illuminance');
    await tapLabel('uint8');
    await tapLabel('uint24 LE');
    await _enter('Unit', 'lx');
    logEvent('Verify the live preview finds the record behind the frame header');
    spotText('Sensor · Illuminance: 65 lx', exact: true).existsOnce();
    await tapLabel('Save parser');
    spotText('Sensor · Illuminance: 65 lx').existsOnce();
    spotText(
      'Service data fff0 · records from 2 · Type, length, value · type 2 bytes LE · 1 field · All devices',
      exact: true,
    ).existsOnce();
  }

  Future<void> filterTrackedHistory() async {
    await tapLabel('Track advertisements');
    logEvent('Receive a repeated frame, an unparsed frame type and a new temperature');
    for (final frame in [_warm, _warm, _otherFrame, _warmer]) {
      platform.advertise(manufacturerData: {_vendorId: frame});
    }
    await idle();
    spotText('4 of 4 recent advertisements', exact: true).existsOnce();

    await tapLabel('Changes only');
    spotText('3 of 4 recent advertisements', exact: true).existsOnce();
    await tapLabel('Parsed only');
    spotText('2 of 4 recent advertisements', exact: true).existsOnce();
    await tapLabel('Changes only');
    spotText('3 of 4 recent advertisements', exact: true).existsOnce();
    await tapLabel('Parsed only');

    logEvent('Filter the history by a parsed value');
    await _enter('Filter history', '25.000');
    spotText('1 of 4 recent advertisements', exact: true).existsOnce();
    spotText('Climate · Temperature: 25.000 °C').existsAtLeastOnce();
    await tapLabel('Stop tracking');
  }

  Future<void> removeParser() async {
    final remove = spot<IconButton>().withTooltip('Remove parser')..existsOnce();
    await tester.ensureVisible(find.byTooltip('Remove parser'));
    await idle();
    await act.tap(remove);
    await idle();
    expect(controller.parsers.where((parser) => parser.name == 'Climate'), isEmpty);
    spotText('Climate · Temperature').doesNotExist();
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

  Future<void> manageGlobalParsers() async {
    await tapLabel('Library');
    logEvent('Verify the bundled test dongle parsers');
    expect(controller.parsers, hasLength(testDongleParsers.length));
    spotText('Manufacturer 0xffff · match 02 at 0 · 8 fields · All devices').existsOnce();
    final remove = spot<IconButton>().withTooltip('Remove parser');
    for (var i = 0; i < testDongleParsers.length; i++) {
      await act.tap(remove.first());
      await idle();
    }
    spotText('No parsers yet.', exact: true).existsOnce();
    await tapLabel('Add test dongle parsers');
    expect(controller.parsers, hasLength(testDongleParsers.length));

    logEvent('Edit a parser without a device context');
    await act.tap(spot<IconButton>().withTooltip('Edit parser').first());
    await idle();
    spotText('Only this device').doesNotExist();
    await _enter('Parser name', 'Battery level');
    await tapLabel('Save parser');
    expect(controller.parsers.first.name, 'Battery level');
    spotText('Battery level', exact: true).existsOnce();
  }
}
