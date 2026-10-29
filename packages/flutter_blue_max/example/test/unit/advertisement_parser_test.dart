import 'dart:convert';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_tracker.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ruuviId = 0x0499;
  const ruuvi = AdvertisementParser(
    name: 'Ruuvi',
    source: AdvertisementSource.manufacturer,
    companyId: ruuviId,
    match: [0x05],
    fields: [
      AdvertisementField('Temperature', 1, AdvertisementFieldType.int16be, scale: 0.005, unit: '°C'),
      AdvertisementField('Humidity', 3, AdvertisementFieldType.uint16be, scale: 0.0025, unit: '%'),
    ],
  );

  test('numeric types honour sign, byte order and scale', () {
    String read(AdvertisementFieldType type, List<int> bytes, {double scale = 1}) =>
        AdvertisementField('Value', 0, type, scale: scale).format(bytes);

    expect(read(AdvertisementFieldType.uint8, [0xff]), '255');
    expect(read(AdvertisementFieldType.int8, [0xff]), '-1');
    expect(read(AdvertisementFieldType.uint16le, [0x34, 0x12]), '4660');
    expect(read(AdvertisementFieldType.uint16be, [0x12, 0x34]), '4660');
    expect(read(AdvertisementFieldType.int16le, [0x18, 0xfc]), '-1000');
    expect(read(AdvertisementFieldType.int16be, [0xfc, 0x18], scale: 0.1), '-100.0');
    expect(read(AdvertisementFieldType.uint32le, [0x78, 0x56, 0x34, 0x12]), '305419896');
    expect(read(AdvertisementFieldType.int32be, [0xff, 0xff, 0xff, 0xfe]), '-2');
    expect(read(AdvertisementFieldType.float32le, [0x00, 0x00, 0xc0, 0x3f]), '1.50');
    expect(read(AdvertisementFieldType.uint8, [10], scale: 2), '20');
    expect(read(AdvertisementFieldType.int16be, [0x15, 0x80], scale: 1 / 256), '21.500');
    expect(read(AdvertisementFieldType.uint8, [3], scale: 0.001), '0.003');
  });

  test('variable-width fields read their configured length', () {
    expect(
      const AdvertisementField('Raw', 1, AdvertisementFieldType.hex, length: 2).format([0, 0xab, 0xcd, 0xef]),
      'AB CD',
    );
    expect(const AdvertisementField('Id', 0, AdvertisementFieldType.ascii, length: 2).format([0x48, 0x69]), 'Hi');
  });

  test('a short payload is reported per field instead of failing the parser', () {
    expect(ruuvi.read(companyId: ruuviId, bytes: [0x05, 0x12, 0xfc]), [
      'Ruuvi · Temperature: 24.300 °C',
      'Ruuvi · Humidity: too short (3 B)',
    ]);
  });

  test('parsers only read payloads of their source and pattern', () {
    expect(ruuvi.read(companyId: 0x004c, bytes: [0x05, 0x12, 0xfc]), isEmpty, reason: 'Other company');
    expect(
      ruuvi.read(companyId: ruuviId, bytes: [0x03, 0x12, 0xfc]),
      isEmpty,
      reason: 'Other frame type',
    );
    expect(
      ruuvi.read(serviceUuid: Guid('fe95'), bytes: [0x05, 0x12, 0xfc]),
      isEmpty,
      reason: 'Other source',
    );
    expect(
      ruuvi.read(companyId: ruuviId, bytes: []),
      isEmpty,
      reason: 'Pattern beyond the payload',
    );

    final mi = AdvertisementParser(
      name: 'Mi',
      source: AdvertisementSource.service,
      serviceUuid: Guid('fe95'),
      match: [0x98, 0x00],
      matchOffset: 2,
      fields: [const AdvertisementField('Counter', 4, AdvertisementFieldType.uint8)],
    );
    final frame = [0x31, 0x02, 0x98, 0x00, 0x07];
    expect(mi.read(serviceUuid: Guid('0000fe95-0000-1000-8000-00805f9b34fb'), bytes: frame), ['Mi · Counter: 7']);
  });

  test('device-bound parsers apply only to their device', () {
    const device = DeviceIdentifier('AA:BB:CC:DD:EE:01');
    const bound = AdvertisementParser(
      name: 'Bound',
      source: AdvertisementSource.manufacturer,
      companyId: ruuviId,
      device: device,
      fields: [],
    );
    expect(bound.appliesTo(device), isTrue);
    expect(bound.appliesTo(const DeviceIdentifier('AA:BB:CC:DD:EE:02')), isFalse);
    expect(ruuvi.appliesTo(device), isTrue);
  });

  test('parsed values follow the payload they were read from', () {
    final data = AdvertisementData(
      advName: 'Sensor',
      txPowerLevel: null,
      appearance: null,
      connectable: false,
      manufacturerData: {
        ruuviId: [0x05, 0x12, 0xfc, 0x53, 0x94],
      },
      serviceData: {
        Guid('fe95'): [0x01],
      },
      serviceUuids: [],
    );
    expect(describeAdvertisement(data, parsers: [ruuvi]), [
      'Name: Sensor',
      'Manufacturer 0x499: 05 12 FC 53 94',
      '  ↳ Ruuvi · Temperature: 24.300 °C',
      '  ↳ Ruuvi · Humidity: 53.490 %',
      'Service data fe95: 01',
    ]);
    expect(parsedValues(data, [ruuvi]), ['Ruuvi · Temperature: 24.300 °C', 'Ruuvi · Humidity: 53.490 %']);
  });

  test('uint24 reads three bytes in either byte order', () {
    expect(const AdvertisementField('Lux', 0, AdvertisementFieldType.uint24le).format([0xe8, 0x03, 0x01]), '66536');
    expect(const AdvertisementField('Lux', 0, AdvertisementFieldType.uint24be).format([0x01, 0x03, 0xe8]), '66536');
  });

  test('parsers survive a JSON round trip unchanged', () {
    final parsers = [ruuvi, ...testDongleParsers];
    final restored = [
      for (final json in jsonDecode(jsonEncode(parsers)) as List)
        AdvertisementParser.fromJson(json as Map<String, dynamic>),
    ];
    expect(jsonEncode(restored), jsonEncode(parsers));
    expect(() => AdvertisementParser.fromJson({'name': 'Broken'}), throwsFormatException);
  });

  group('Test dongle parsers', () {
    List<String> read(List<int> bytes) => [
      for (final parser in testDongleParsers) ...parser.read(companyId: 0xffff, bytes: bytes),
    ];

    test('status frame', () {
      expect(read([0x01, 0x00, 0x01, 0x05, 0x39, 0x30, 0x07]), [
        'FBM status · Mode: 0',
        'FBM status · Platform: 1',
        'FBM status · Flags: 05',
        'FBM status · Counter: 12345',
        'FBM status · Button: 7',
      ]);
    });

    test('sensor frame for counter 1234 after 70000 s', () {
      final frame = [
        0x02, 0xd2, 0x04, 0x00, 0x00, 0x60, 0x09, 0x16, 0x10, 0x68, 0x00, 0x40, 0x7e, 0x44, //
        0xd2, 0x70, 0x11, 0x01, 0x46, 0x42, 0x4d, 0x32, 0x33, 0x34,
      ];
      expect(read(frame), [
        'FBM sensor · Counter: 1234',
        'FBM sensor · Temperature: 24.00 °C',
        'FBM sensor · Humidity: 22 %',
        'FBM sensor · Battery: 4200 mV',
        'FBM sensor · Pressure: 1017.00 hPa',
        'FBM sensor · Delta: -46',
        'FBM sensor · Uptime: 70000 s',
        'FBM sensor · Tag: FBM234',
      ]);
    });

    test('other frame types and companies are ignored', () {
      expect(read([0x03, 0x00]), isEmpty);
      expect(testDongleParsers.first.read(companyId: 0x004c, bytes: [0x01, 0, 0, 0, 0, 0, 0]), isEmpty);
    });
  });
}
