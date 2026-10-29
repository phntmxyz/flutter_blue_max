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
    expect(knownService(Guid('0000180f-0000-1000-8000-00805f9b34fb'))?.name, 'Battery');
    expect(knownService(Guid('7e570001-85d8-4594-ac4f-b32fc01e9a49'))?.test, isTrue);
    expect(knownService(Guid('fff0')), isNull);
  });
}
