import 'dart:convert';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('properties must match exactly, ignoring flags the explorer does not show', () {
    final echo = KnownCharacteristic(Guid('2a19'), 'Level', properties: {GattProperty.read, GattProperty.notify});
    expect(echo.matches(const CharacteristicProperties(read: true, notify: true, broadcast: true)), isTrue);
    expect(echo.matches(const CharacteristicProperties(read: true)), isFalse);
    expect(echo.matches(const CharacteristicProperties(read: true, notify: true, write: true)), isFalse);
    expect(KnownCharacteristic(Guid('2a19'), 'Level').matches(const CharacteristicProperties()), isTrue);
  });

  test('only test services report missing characteristics', () {
    final empty = BluetoothService.fromProto(
      BmBluetoothService(
        remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:01'),
        serviceUuid: Guid('180f'),
        primaryServiceUuid: null,
        characteristics: [],
      ),
    );
    final standard = KnownService(Guid('180f'), 'Battery', [KnownCharacteristic(Guid('2a19'), 'Level')]);
    final test = KnownService(Guid('180f'), 'Battery', test: true, [KnownCharacteristic(Guid('2a19'), 'Level')]);
    expect(standard.compare(empty).missing, isEmpty);
    expect(test.compare(empty).missing, ['Level']);
    expect(test.compare(empty).different, isEmpty);
  });

  test('catalog entries are found by short and full UUID', () {
    expect(builtInService(Guid('0000180f-0000-1000-8000-00805f9b34fb'))?.name, 'Battery');
    expect(builtInService(Guid('7e570001-85d8-4594-ac4f-b32fc01e9a49'))?.test, isTrue);
    expect(builtInService(Guid('fff0')), isNull);
  });

  test('every service and characteristic appears once', () {
    final services = [...testDongleServices, ...standardServices];
    expect(services.map((service) => service.uuid).toSet(), hasLength(services.length));
    for (final service in services) {
      expect(
        service.characteristics.map((characteristic) => characteristic.uuid).toSet(),
        hasLength(service.characteristics.length),
        reason: service.name,
      );
    }
  });

  test('catalog services survive a JSON round trip unchanged', () {
    final services = [
      ...testDongleServices,
      ...standardServices,
      KnownService(Guid('fff0'), 'Mixed', [
        KnownCharacteristic(Guid('fff1'), 'Unchecked'),
        KnownCharacteristic(Guid('fff2'), 'Empty', properties: {}),
      ]),
    ];
    final restored = [
      for (final json in jsonDecode(jsonEncode(services)) as List) KnownService.fromJson(json as Map<String, dynamic>),
    ];
    expect(jsonEncode(restored), jsonEncode(services));
    expect(restored.last.characteristics.first.properties, isNull);
    expect(() => KnownService.fromJson({'name': 'Broken'}), throwsFormatException);
  });
}
