import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_editor_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:spot/spot.dart';

void main() {
  testWidgets('preview uses the same cross-field validation as saving', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ParserEditorPage(
          initial: const AdvertisementParser(
            name: 'Sensor',
            source: AdvertisementSource.manufacturer,
            companyId: 0xffff,
            fields: [AdvertisementField('Value', 0, AdvertisementFieldType.uint8)],
          ),
          advertisement: AdvertisementData(
            advName: '',
            txPowerLevel: null,
            appearance: null,
            connectable: false,
            manufacturerData: {
              0xffff: [42],
            },
            serviceData: {},
            serviceUuids: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final form = (spot<ReactiveForm>()..existsOnce()).snapshotWidget().formGroup;
    final field = (form.control('fields') as FormArray<Map<String, dynamic>>).controls.single as FormGroup;
    spotText('Sensor · Value: 42', exact: true).existsOnce();

    for (final invalid in [
      (form.control('name'), ''),
      (field.control('offset'), '-1'),
      (field.control('scale'), '0'),
      (field.control('bits'), '9'),
    ]) {
      final control = invalid.$1;
      final previous = control.value;
      control.value = invalid.$2;
      await tester.pumpAndSettle();
      expect(form.valid, isFalse);
      spotText('Complete the form to preview.', exact: true).existsOnce();
      spotText('Sensor · Value: 42', exact: true).doesNotExist();
      control.value = previous;
      await tester.pumpAndSettle();
      expect(form.valid, isTrue);
      spotText('Sensor · Value: 42', exact: true).existsOnce();
    }

    field.control('bit').value = '7';
    field.control('bits').value = '2';
    await tester.pumpAndSettle();
    expect(form.valid, isFalse, reason: 'bit width includes the starting bit');
    form.control('records').value = true;
    field.control('record').value = '100';
    field.control('bits').value = '';
    await tester.pumpAndSettle();
    expect(form.valid, isFalse, reason: 'record identifiers must fit the selected record width');
    form.control('recordType').value = RecordTypeFormat.uint16le;
    await tester.pumpAndSettle();
    expect(form.valid, isTrue);
  });
}
