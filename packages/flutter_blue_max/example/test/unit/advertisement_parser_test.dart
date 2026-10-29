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

  final sensor = AdvertisementParser(
    name: 'Sensor',
    source: AdvertisementSource.service,
    serviceUuid: Guid('fff0'),
    records: const RecordFormat(offset: 2, type: RecordTypeFormat.uint16le),
    fields: const [
      AdvertisementField('Temperature', 0, AdvertisementFieldType.int16le, scale: 0.1, unit: '°C', record: 0x0001),
      AdvertisementField('Illuminance', 0, AdvertisementFieldType.uint24le, unit: 'lx', record: 0x0002),
      AdvertisementField('Moisture', 0, AdvertisementFieldType.uint8, unit: '%', record: 0x0003),
    ],
  );
  final bthome = AdvertisementParser(
    name: 'BTHome',
    source: AdvertisementSource.service,
    serviceUuid: Guid('fcd2'),
    match: const [0x40],
    records: const RecordFormat(offset: 1, length: RecordLength.implied),
    fields: const [
      AdvertisementField('Battery', 0, AdvertisementFieldType.uint8, unit: '%', record: 0x01),
      AdvertisementField('Temperature', 0, AdvertisementFieldType.int16le, scale: 0.01, unit: '°C', record: 0x02),
      AdvertisementField('Humidity', 0, AdvertisementFieldType.uint16le, scale: 0.01, unit: '%', record: 0x03),
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
      ruuvi.read(serviceUuid: Guid('fff0'), bytes: [0x05, 0x12, 0xfc]),
      isEmpty,
      reason: 'Other source',
    );
    expect(
      ruuvi.read(companyId: ruuviId, bytes: []),
      isEmpty,
      reason: 'Pattern beyond the payload',
    );

    final vendor = AdvertisementParser(
      name: 'Vendor',
      source: AdvertisementSource.service,
      serviceUuid: Guid('fff0'),
      match: [0x12, 0x34],
      matchOffset: 2,
      fields: [const AdvertisementField('Counter', 4, AdvertisementFieldType.uint8)],
    );
    final frame = [0x31, 0x02, 0x12, 0x34, 0x07];
    expect(vendor.read(serviceUuid: Guid('0000fff0-0000-1000-8000-00805f9b34fb'), bytes: frame), [
      'Vendor · Counter: 7',
    ]);
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
        Guid('fff0'): [0x01],
      },
      serviceUuids: [],
    );
    expect(describeAdvertisement(data, parsers: [ruuvi]), [
      'Name: Sensor',
      'Manufacturer 0x499: 05 12 FC 53 94',
      '  ↳ Ruuvi · Temperature: 24.300 °C',
      '  ↳ Ruuvi · Humidity: 53.490 %',
      'Service data fff0: 01',
    ]);
    expect(parsedValues(data, [ruuvi]), ['Ruuvi · Temperature: 24.300 °C', 'Ruuvi · Humidity: 53.490 %']);
  });

  test('uint24 reads three bytes in either byte order', () {
    expect(const AdvertisementField('Lux', 0, AdvertisementFieldType.uint24le).format([0xe8, 0x03, 0x01]), '66536');
    expect(const AdvertisementField('Lux', 0, AdvertisementFieldType.uint24be).format([0x01, 0x03, 0xe8]), '66536');
  });

  group('Records', () {
    // Frame type and counter precede the records.
    const header = [0x10, 0x5a];
    List<String> read(List<int> records) => sensor.read(serviceUuid: Guid('fff0'), bytes: [...header, ...records]);

    test('a frame reads only the records it carries, in any order', () {
      expect(read([0x02, 0x00, 0x03, 0x41, 0x00, 0x00]), ['Sensor · Illuminance: 65 lx']);
      expect(read([0x03, 0x00, 0x01, 0x2a, 0x01, 0x00, 0x02, 0xd2, 0x00]), [
        'Sensor · Temperature: 21.0 °C',
        'Sensor · Moisture: 42 %',
      ]);
    });

    test('a truncated record is reported after the values read before it', () {
      expect(read([0x03, 0x00, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x41]), [
        'Sensor · Moisture: 42 %',
        'Sensor · record 0x0002 truncated at 6',
      ]);
      expect(read([0x02]), ['Sensor · record header truncated at 2']);
    });

    test('records without a length byte take their size from the fields', () {
      List<String> read(List<int> bytes) => bthome.read(serviceUuid: Guid('fcd2'), bytes: bytes);

      expect(read([0x40, 0x02, 0xca, 0x09, 0x01, 0x61, 0x03, 0xbf, 0x13]), [
        'BTHome · Battery: 97 %',
        'BTHome · Temperature: 25.06 °C',
        'BTHome · Humidity: 50.55 %',
      ], reason: 'Order of the records does not matter');
      expect(read([0x40, 0x01, 0x61, 0x05, 0x10, 0x27, 0x00, 0x03, 0xbf, 0x13]), [
        'BTHome · Battery: 97 %',
        'BTHome · unknown record 0x05 at 3',
      ], reason: 'An unknown size ends the split');
      expect(read([0x41, 0x01, 0x61]), isEmpty, reason: 'Encrypted frames do not match');
    });

    test('a length byte before the type counts the type, and zero ends the records', () {
      const parser = AdvertisementParser(
        name: 'AD',
        source: AdvertisementSource.manufacturer,
        companyId: 0xffff,
        records: RecordFormat(length: RecordLength.beforeType),
        fields: [AdvertisementField('Name', 0, AdvertisementFieldType.ascii, length: 2, record: 0x09)],
      );
      expect(parser.read(companyId: 0xffff, bytes: [0x02, 0x01, 0x06, 0x03, 0x09, 0x48, 0x69, 0x00, 0xff]), [
        'AD · Name: Hi',
      ]);
    });

    test('summaries name the record layout and types', () {
      expect(
        sensor.summary,
        'Service data fff0 · records from 2 · Type, length, value · type 2 bytes LE · 3 fields · All devices',
      );
      expect(sensor.fields.first.summary(sensor.records), 'Temperature: int16 LE · record 0x0001');
      expect(bthome.fields.first.summary(bthome.records), 'Battery: uint8 · record 0x01');
    });
  });

  group('Bit ranges', () {
    // Ruuvi RAWv2 power info: 11 bits battery voltage above 1600 mV, 5 bits TX power in 2 dB steps above -40 dBm.
    const power = [0xac, 0x36];

    test('read packed values from the least significant bit', () {
      const voltage = AdvertisementField(
        'Voltage',
        0,
        AdvertisementFieldType.uint16be,
        add: 1600,
        unit: 'mV',
        bit: 5,
        bits: 11,
      );
      const txPower = AdvertisementField(
        'TX power',
        0,
        AdvertisementFieldType.uint16be,
        scale: 2,
        add: -40,
        unit: 'dBm',
        bits: 5,
      );
      expect(voltage.format(power), '2977 mV');
      expect(txPower.format(power), '4 dBm');
      expect(const AdvertisementField('Flag', 0, AdvertisementFieldType.uint8, bit: 2, bits: 1).format([0x04]), '1');
      expect(voltage.summary(null), 'Voltage: uint16 BE · bits 5–15');
      expect(
        const AdvertisementField('Flag', 0, AdvertisementFieldType.uint8, bit: 2, bits: 1).summary(null),
        'Flag: uint8 · bit 2',
      );
    });

    test('report ranges they cannot read', () {
      expect(
        const AdvertisementField('Signed', 0, AdvertisementFieldType.int16be, bits: 4).format(power),
        'bits need an unsigned type',
      );
      expect(
        const AdvertisementField('Wide', 0, AdvertisementFieldType.uint8, bit: 4, bits: 5).format(power),
        'bits beyond 8-bit value',
      );
    });
  });

  test('add shifts the scaled value', () {
    expect(
      const AdvertisementField(
        'Offset',
        0,
        AdvertisementFieldType.uint8,
        scale: 0.5,
        add: -20,
        unit: '°C',
      ).format([50]),
      '5.0 °C',
    );
  });

  test('parsers survive a JSON round trip unchanged', () {
    final parsers = [ruuvi, sensor, bthome, ...testDongleParsers];
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
