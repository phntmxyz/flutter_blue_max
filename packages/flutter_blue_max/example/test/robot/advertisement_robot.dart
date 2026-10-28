import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import 'workbench_robot.dart';

/// Ruuvi RAWv2 frames: frame type 0x05, then the temperature as int16 BE in 0.005 °C.
const _ruuviId = 0x0499;
const _warm = [0x05, 0x12, 0xfc];
const _warmer = [0x05, 0x13, 0x88];
const _otherFrame = [0x03, 0x00, 0x00];

/// Parsers and history filters, driven through the device inspector.
extension AdvertisementRobot on WorkbenchRobot {
  Future<void> scanForSensor() async {
    await tapLabel('Start scan');
    logEvent('Receive a sensor advertisement with manufacturer data');
    platform.advertise(manufacturerData: {_ruuviId: _warm});
    await idle();
    await tapLabel('Stop scan');
    await selectPeripheral();
    await tapLabel('Advertisement');
  }

  Future<void> addTemperatureParser() async {
    await tapLabel('Add parser');
    logEvent('Verify that the source is prefilled from the latest advertisement');
    expect(_field('Company ID (hex)').snapshotWidget().controller!.text, '0x0499');
    await _enter('Parser name', 'Ruuvi');
    await _enter('Bytes (hex)', '05');
    await _enter('Field name', 'Temperature');
    await _enter('Offset', '1');
    await tapLabel('uint8');
    await tapLabel('int16 BE');
    await _enter('Scale', '0.005');
    await _enter('Unit', '°C');
    logEvent('Verify the live preview against the sample bytes');
    spotText('Ruuvi · Temperature: 24.300 °C', exact: true).existsOnce();
    await tapLabel('Save parser');
    spotText('Ruuvi · Temperature: 24.300 °C').existsOnce();
    spotText('Manufacturer 0x499 · match 05 at 0 · 1 field · All devices', exact: true).existsOnce();
    logEvent('Verify that unrelated global parsers do not crowd the device');
    spotText('iBeacon').doesNotExist();
  }

  Future<void> filterTrackedHistory() async {
    await tapLabel('Track advertisements');
    logEvent('Receive a repeated frame, an unparsed frame type and a new temperature');
    for (final frame in [_warm, _warm, _otherFrame, _warmer]) {
      platform.advertise(manufacturerData: {_ruuviId: frame});
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
    spotText('Ruuvi · Temperature: 25.000 °C').existsAtLeastOnce();
    await tapLabel('Stop tracking');
  }

  Future<void> removeParser() async {
    final remove = spot<IconButton>().withTooltip('Remove parser')..existsOnce();
    await tester.ensureVisible(find.byTooltip('Remove parser'));
    await idle();
    await act.tap(remove);
    await idle();
    expect(controller.parsers.where((parser) => parser.name == 'Ruuvi'), isEmpty);
    spotText('Ruuvi · Temperature').doesNotExist();
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
    await tapLabel('Parsers');
    logEvent('Verify the bundled common examples');
    expect(controller.parsers, hasLength(commonParsers.length));
    spotText('Manufacturer 0x4c · match 02 15 at 0 · 4 fields · All devices').existsOnce();
    final remove = spot<IconButton>().withTooltip('Remove parser');
    for (var i = 0; i < commonParsers.length; i++) {
      await act.tap(remove.first());
      await idle();
    }
    spotText('No parsers yet.', exact: true).existsOnce();
    await tapLabel('Add common examples');
    expect(controller.parsers, hasLength(commonParsers.length));

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
