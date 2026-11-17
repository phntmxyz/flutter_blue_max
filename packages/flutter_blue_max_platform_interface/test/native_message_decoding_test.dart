import 'dart:typed_data';

import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan messages decode standard codec maps and typed byte buffers', () {
    final response = BmScanResponse.fromMap(<Object?, Object?>{
      'advertisements': <Object?>[
        <Object?, Object?>{
          'remote_id': 'native-peer',
          'platform_name': 'Sensor',
          'connectable': 1,
          'manufacturer_data': <Object?, Object?>{
            0xffff: Uint8List.fromList([1, 2])
          },
          'service_data': <Object?, Object?>{
            '180f': Uint8List.fromList([42])
          },
          'service_uuids': <Object?>['180f'],
          'rssi': -47,
        },
      ],
    });
    final advertisement = response.advertisements.single;
    expect(response.success, isTrue);
    expect(advertisement.remoteId, const DeviceIdentifier('native-peer'));
    expect(advertisement.manufacturerData, {
      0xffff: [1, 2]
    });
    expect(advertisement.serviceData, {
      Guid('180f'): [42]
    });
    expect(advertisement.serviceUuids, [Guid('180f')]);
    expect(advertisement.advName, isNull);
    expect(advertisement.txPowerLevel, isNull);
    expect(advertisement.connectable, isTrue);
    expect(advertisement.rssi, -47);
  });

  test(
      'device lists and nested GATT maps retain optional identities and properties',
      () {
    final devices = BmDevicesList.fromMap(<Object?, Object?>{
      'devices': <Object?>[
        <Object?, Object?>{
          'remote_id': 'native-peer',
          'platform_name': 'Sensor'
        },
      ],
    });
    expect(
        devices.devices.single.remoteId, const DeviceIdentifier('native-peer'));
    final service = BmBluetoothService.fromMap(<Object?, Object?>{
      'remote_id': 'native-peer',
      'service_uuid': '180f',
      'characteristics': <Object?>[
        <Object?, Object?>{
          'remote_id': 'native-peer',
          'service_uuid': '180f',
          'characteristic_uuid': '2a19',
          'properties': <Object?, Object?>{
            for (final key in [
              'broadcast',
              'write_without_response',
              'write',
              'indicate',
              'authenticated_signed_writes',
              'extended_properties',
              'notify_encryption_required',
              'indicate_encryption_required',
            ])
              key: 0,
            'read': 1,
            'notify': 1,
          },
          'descriptors': <Object?>[
            <Object?, Object?>{
              'remote_id': 'native-peer',
              'service_uuid': '180f',
              'characteristic_uuid': '2a19',
              'descriptor_uuid': '2902',
            },
          ],
        },
      ],
    });
    final characteristic = service.characteristics.single;
    expect(service.primaryServiceUuid, isNull);
    expect(characteristic.instanceId, isNull);
    expect(characteristic.properties.read, isTrue);
    expect(characteristic.properties.notify, isTrue);
    expect(characteristic.properties.write, isFalse);
    expect(characteristic.descriptors.single.descriptorUuid, Guid('2902'));
  });

  test('L2CAP response initializers decode native integers and typed buffers',
      () {
    expect(
        ListenL2CapChannelResponse.fromMap(<Object?, Object?>{'psm': 129}).psm,
        129);
    final response = ReadL2CapChannelResponse.fromMap(<Object?, Object?>{
      'remote_id': 'native-peer',
      'psm': 129,
      'bytes_read': 2,
      'value': Uint8List.fromList([65, 66]),
    });
    expect(response.remoteId, 'native-peer');
    expect(response.psm, 129);
    expect(response.bytesRead, 2);
    expect(response.value, [65, 66]);
  });

  test('malformed native types still fail at the decoding boundary', () {
    expect(() => ListenL2CapChannelResponse.fromMap({'psm': '129'}),
        throwsA(isA<TypeError>()));
    expect(
        () => BmDevicesList.fromMap({
              'devices': [42]
            }),
        throwsA(isA<TypeError>()));
  });
}
