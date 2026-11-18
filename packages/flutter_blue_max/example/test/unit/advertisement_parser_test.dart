import 'dart:convert';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_tracker.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reserved by the Bluetooth SIG for testing.
  const testCompany = 0xffff;
  const climate = AdvertisementParser(
    name: 'Climate',
    source: AdvertisementSource.manufacturer,
    companyId: testCompany,
    match: [0x10],
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

  test('service-data parser imports reject empty UUIDs and accept explicit UUIDs', () {
    final json = sensor.toJson();
    for (final input in ['', '   ']) {
      expect(() => AdvertisementParser.fromJson({...json, 'serviceUuid': input}), throwsFormatException);
    }
    expect(AdvertisementParser.fromJson(json).serviceUuid, Guid('fff0'));
  });

  test('parser imports enforce the record ID width used by the editor', () {
    for (final type in RecordTypeFormat.values) {
      final maxId = (1 << (8 * type.size)) - 1;
      final parser = {...sensor.toJson(), 'records': RecordFormat(type: type).toJson()};
      final field = sensor.fields.first.toJson();
      Map<String, dynamic> fixture(int? id) => {
        ...parser,
        'fields': [
          {...field, 'record': id},
        ],
      };
      for (final id in [null, -1, maxId + 1]) {
        expect(type.canReadId(id), isFalse);
        expect(() => AdvertisementParser.fromJson(fixture(id)), throwsFormatException);
      }
      expect(type.canReadId(maxId), isTrue);
      expect(AdvertisementParser.fromJson(fixture(maxId)).fields.single.record, maxId);
    }
  });

  test('large offsets and sizes report short payloads without overflow', () {
    final large = int.tryParse('9223372036854775807') ?? 0x1fffffffffffff;
    final field = AdvertisementField('Far away', large, AdvertisementFieldType.hex, length: large, record: 1);
    expect(field.format([1, 2]), 'too short (2 B)');

    final pattern = AdvertisementParser(
      name: 'Pattern',
      source: AdvertisementSource.manufacturer,
      companyId: 1,
      matchOffset: large,
      match: [1, 2],
      fields: [field],
    );
    expect(pattern.read(companyId: 1, bytes: [1, 2]), isEmpty);

    final implied = AdvertisementParser(
      name: 'Implied',
      source: AdvertisementSource.manufacturer,
      companyId: 1,
      records: const RecordFormat(length: RecordLength.implied),
      fields: [field],
    );
    expect(implied.read(companyId: 1, bytes: [1, 2]), ['Implied · record 0x01 truncated at 0']);
  });

  test('numeric displays preserve a fractional add value', () {
    const field = AdvertisementField('Value', 0, AdvertisementFieldType.uint8, scale: 2, add: 0.125);
    expect(field.format([1]), '2.125');
  });

  test('length-first records distinguish invalid sizes from missing header bytes', () {
    const parser = AdvertisementParser(
      name: 'AD',
      source: AdvertisementSource.manufacturer,
      companyId: 1,
      records: RecordFormat(type: RecordTypeFormat.uint16le, length: RecordLength.beforeType),
      fields: [],
    );
    expect(parser.read(companyId: 1, bytes: [1, 2]), ['AD · record header truncated at 0']);
    expect(parser.read(companyId: 1, bytes: [1, 2, 3]), ['AD · record length 1 is smaller than the 2-byte type at 0']);
  });

  test('legacy parser fields default later optional settings without accepting malformed values', () {
    final parser = AdvertisementParser.fromJson({
      'name': 'Legacy',
      'source': 'manufacturer',
      'companyId': 0x59,
      'fields': [
        {'name': 'Counter', 'offset': 0, 'type': 'uint8'},
      ],
    });
    final field = parser.fields.single;
    expect([field.scale, field.add, field.bit, field.length, field.unit], [1, 0, 0, 1, '']);
    expect(field.format([42]), '42');
    expect(parser.match, isEmpty);
    expect(parser.matchOffset, 0);
    expect(
      () => AdvertisementField.fromJson({'name': 'Counter', 'offset': 0, 'type': 'uint8', 'bit': 'wrong'}),
      throwsFormatException,
    );
  });

  test('decoded parsers retain immutable payload patterns and fields', () {
    final json = testDongleParsers.first.toJson();
    final match = List<int>.from(json['match'] as List);
    final fields = List<Object?>.from(json['fields'] as List);
    json['match'] = match;
    json['fields'] = fields;
    final parser = AdvertisementParser.fromJson(json);
    final expectedMatch = List.of(parser.match);
    final expectedFields = List.of(parser.fields);
    match.clear();
    fields.clear();
    expect(parser.match, expectedMatch);
    expect(parser.fields, expectedFields);
    expect(() => parser.match.add(1), throwsUnsupportedError);
    expect(() => parser.fields.clear(), throwsUnsupportedError);
  });

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
    expect(climate.read(companyId: testCompany, bytes: [0x10, 0x0f, 0xa0]), [
      'Climate · Temperature: 20.000 °C',
      'Climate · Humidity: too short (3 B)',
    ]);
  });

  test('parsers only read payloads of their source and pattern', () {
    expect(climate.read(companyId: 0xfffe, bytes: [0x10, 0x0f, 0xa0]), isEmpty, reason: 'Other company');
    expect(
      climate.read(companyId: testCompany, bytes: [0x11, 0x0f, 0xa0]),
      isEmpty,
      reason: 'Other frame type',
    );
    expect(
      climate.read(serviceUuid: Guid('fff0'), bytes: [0x10, 0x0f, 0xa0]),
      isEmpty,
      reason: 'Other source',
    );
    expect(
      climate.read(companyId: testCompany, bytes: []),
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
      companyId: testCompany,
      device: device,
      fields: [],
    );
    expect(bound.appliesTo(device), isTrue);
    expect(bound.appliesTo(const DeviceIdentifier('AA:BB:CC:DD:EE:02')), isFalse);
    expect(climate.appliesTo(device), isTrue);
  });

  test('parsed values follow the payload they were read from', () {
    final data = AdvertisementData(
      advName: 'Sensor',
      txPowerLevel: null,
      appearance: null,
      connectable: false,
      manufacturerData: {
        testCompany: [0x10, 0x0f, 0xa0, 0x4e, 0x20],
      },
      serviceData: {
        Guid('fff0'): [0x01],
      },
      serviceUuids: [],
    );
    expect(describeAdvertisement(data, parsers: [climate]), [
      'Name: Sensor',
      'Manufacturer 0xffff: 10 0F A0 4E 20',
      '  ↳ Climate · Temperature: 20.000 °C',
      '  ↳ Climate · Humidity: 50.000 %',
      'Service data fff0: 01',
    ]);
    expect(parsedValues(data, [climate]), ['Climate · Temperature: 20.000 °C', 'Climate · Humidity: 50.000 %']);
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
    // A packed power word: 11 bits battery voltage above 1600 mV, 5 bits TX power in 2 dB steps above -40 dBm.
    const power = [0xaf, 0x17];

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
      expect(voltage.format(power), '3000 mV');
      expect(txPower.format(power), '6 dBm');
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

  test('a zero or non-finite scale never breaks formatting and is rejected when decoded', () {
    for (final scale in [0.0, double.nan, double.infinity]) {
      expect(AdvertisementField('Value', 0, AdvertisementFieldType.uint8, scale: scale).format([4]), isA<String>());
      expect(
        AdvertisementField('Value', 0, AdvertisementFieldType.float32le, scale: scale).format([0, 0, 0, 0]),
        isA<String>(),
      );
    }
    final json = const AdvertisementField('Value', 0, AdvertisementFieldType.uint8).toJson();
    expect(() => AdvertisementField.fromJson({...json, 'scale': 0}), throwsFormatException);
    expect(() => AdvertisementField.fromJson({...json, 'scale': double.infinity}), throwsFormatException);
    expect(() => AdvertisementField.fromJson({...json, 'add': double.nan}), throwsFormatException);
  });

  test('parsers survive a JSON round trip unchanged', () {
    final parsers = [climate, sensor, bthome, ...testDongleParsers];
    final restored = [
      for (final json in jsonDecode(jsonEncode(parsers)) as List)
        AdvertisementParser.fromJson(json as Map<String, dynamic>),
    ];
    expect(jsonEncode(restored), jsonEncode(parsers));
    expect(() => AdvertisementParser.fromJson({'name': 'Broken'}), throwsFormatException);
  });

  test('the tracker bounds its history but averages the interval over the whole session', () {
    final tracker = AdvertisementTracker(const DeviceIdentifier('AA:BB:CC:DD:EE:01'));
    final start = DateTime(2026);
    // Every 100 ms, the last one 50 ms late, so the average depends on both the span and the count.
    final times = [
      for (var i = 0; i <= AdvertisementTracker.maxHistoryEntries; i++)
        start.add(Duration(milliseconds: i * 100 + (i == AdvertisementTracker.maxHistoryEntries ? 50 : 0))),
    ];
    for (final time in times) {
      tracker.record(
        ScanResult(
          device: BluetoothDevice(remoteId: tracker.remoteId),
          advertisementData: AdvertisementData(
            advName: 'Sensor',
            txPowerLevel: null,
            appearance: null,
            connectable: true,
            manufacturerData: const {},
            serviceData: const {},
            serviceUuids: const [],
          ),
          rssi: -60,
          timeStamp: time,
        ),
      );
    }
    expect(tracker.count, AdvertisementTracker.maxHistoryEntries + 1);
    expect(tracker.history, hasLength(AdvertisementTracker.maxHistoryEntries));
    expect(tracker.history.first.time, times.last);
    expect(tracker.history.last.time, times[1], reason: 'the oldest advertisement is evicted');
    expect(tracker.averageInterval, const Duration(microseconds: 100250));
  });

  test('decoding rejects parsers the editor would not save', () {
    final parser = climate.toJson();
    final field = {...(parser['fields'] as List).first as Map<String, dynamic>, 'type': 'uint8'};
    final rejected = <Map<String, dynamic>>[
      {...parser, 'companyId': null},
      {...parser, 'companyId': 0x10000},
      {...parser, 'source': 'service'},
      {...parser, 'matchOffset': -1},
      {
        ...parser,
        'match': [256],
      },
      {
        ...parser,
        'records': {...const RecordFormat().toJson(), 'offset': -1},
      },
      for (final change in {'offset': -1, 'length': 0, 'bit': -1, 'bits': 0}.entries)
        {
          ...parser,
          'fields': [
            {...field, change.key: change.value},
          ],
        },
      {
        ...parser,
        'fields': [
          {...field, 'bit': 4, 'bits': 5},
        ],
      },
      {
        ...parser,
        'fields': [
          {...field, 'type': 'int8', 'bits': 1},
        ],
      },
    ];
    for (final json in rejected) {
      expect(() => AdvertisementParser.fromJson(json), throwsFormatException, reason: '$json');
    }
    expect(
      AdvertisementParser.fromJson({
        ...parser,
        'fields': [
          {...field, 'bit': 4, 'bits': 4},
        ],
      }).fields.single.bits,
      4,
    );
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
      expect(testDongleParsers.first.read(companyId: 0xfffe, bytes: [0x01, 0, 0, 0, 0, 0, 0]), isEmpty);
    });
  });
}
