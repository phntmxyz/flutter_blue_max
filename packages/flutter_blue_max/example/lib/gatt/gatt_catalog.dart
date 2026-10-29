import 'dart:convert';

import 'package:flutter_blue_max/flutter_blue_max.dart';

/// The characteristic properties the GATT explorer shows and the catalog compares.
enum GattProperty(final String label) {
  read('Read'),
  write('Write'),
  writeWithoutResponse('Write without response'),
  notify('Notify'),
  indicate('Indicate');

  static Set<GattProperty> of(CharacteristicProperties properties) => {
    if (properties.read) read,
    if (properties.write) write,
    if (properties.writeWithoutResponse) writeWithoutResponse,
    if (properties.notify) notify,
    if (properties.indicate) indicate,
  };
}

/// A characteristic name and, for test services, the exact properties it must report.
class const KnownCharacteristic(final Guid uuid, final String name, {final Set<GattProperty>? properties}) {
  /// Throws a [FormatException] for stored data that no longer describes a characteristic.
  factory fromJson(Map<String, dynamic> json) {
    try {
      final properties = json['properties'] as List?;
      return KnownCharacteristic(
        Guid(json['uuid'] as String),
        json['name'] as String,
        properties: properties == null
            ? null
            : {for (final property in properties) GattProperty.values.byName(property as String)},
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid catalog characteristic: $error');
    }
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid.str128,
    'name': name,
    'properties': properties == null
        ? null
        : [
            for (final property in GattProperty.values)
              if (properties!.contains(property)) property.name,
          ],
  };

  /// True when nothing is expected or [reported] are exactly the expected properties.
  bool matches(CharacteristicProperties reported) {
    final expected = properties;
    if (expected == null) {
      return true;
    }
    final actual = GattProperty.of(reported);
    return actual.length == expected.length && actual.containsAll(expected);
  }
}

/// A service name and its known characteristics.
/// A [test] service must contain every listed characteristic with exactly its properties.
class const KnownService(
  final Guid uuid,
  final String name,
  final List<KnownCharacteristic> characteristics, {
  final bool test = false,
}) {
  /// Throws a [FormatException] for stored data that no longer describes a service.
  factory fromJson(Map<String, dynamic> json) {
    try {
      return KnownService(Guid(json['uuid'] as String), json['name'] as String, [
        for (final characteristic in json['characteristics'] as List)
          KnownCharacteristic.fromJson(characteristic as Map<String, dynamic>),
      ], test: json['test'] as bool);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid catalog service: $error');
    }
  }

  /// A test entry for [discovered], named by its User Descriptions where it has them.
  factory fromDiscovered(BluetoothService discovered) => KnownService(discovered.uuid, '', test: true, [
    for (final characteristic in discovered.characteristics)
      KnownCharacteristic(
        characteristic.uuid,
        userDescription(characteristic) ?? '',
        properties: GattProperty.of(characteristic.properties),
      ),
  ]);

  Map<String, dynamic> toJson() => {
    'uuid': uuid.str128,
    'name': name,
    'test': test,
    'characteristics': [for (final characteristic in characteristics) characteristic.toJson()],
  };

  KnownCharacteristic? characteristic(Guid uuid) {
    for (final characteristic in characteristics) {
      if (characteristic.uuid == uuid) {
        return characteristic;
      }
    }
    return null;
  }

  /// Names of characteristics [discovered] lacks or reports with other properties; empty unless [test].
  ({List<String> missing, List<String> different}) compare(BluetoothService discovered) {
    if (!test) {
      return (missing: const [], different: const []);
    }
    final missing = <String>[];
    final different = <String>[];
    for (final known in characteristics) {
      final matching = [
        for (final characteristic in discovered.characteristics)
          if (characteristic.uuid == known.uuid) characteristic,
      ];
      if (matching.isEmpty) {
        missing.add(known.name);
      } else if (!matching.every((characteristic) => known.matches(characteristic.properties))) {
        different.add(known.name);
      }
    }
    return (missing: missing, different: different);
  }
}

/// Characteristic User Description: a peripheral's own label for a characteristic.
final userDescriptionUuid = Guid('2901');

/// The last read User Description, or null before it was read or if there is none.
String? userDescription(BluetoothCharacteristic characteristic) {
  for (final descriptor in characteristic.descriptors) {
    if (descriptor.uuid == userDescriptionUuid) {
      final text = utf8.decode(descriptor.lastValue, allowMalformed: true).trim();
      return text.isEmpty ? null : text;
    }
  }
  return null;
}

/// The built-in entry for [uuid]; the controller looks up the user's own entries first.
KnownService? builtInService(Guid uuid) {
  for (final service in [...testDongleServices, ...standardServices]) {
    if (service.uuid == uuid) {
      return service;
    }
  }
  return null;
}

/// UUIDs of the FBM test dongle firmware share one base; [shortId] is its `xxxx` part.
Guid _fbm(int shortId) => Guid('7e57${shortId.toRadixString(16).padLeft(4, '0')}-85d8-4594-ac4f-b32fc01e9a49');

const _r = GattProperty.read;
const _w = GattProperty.write;
const _wnr = GattProperty.writeWithoutResponse;
const _n = GattProperty.notify;
const _i = GattProperty.indicate;

/// The GATT database of the FBM test dongle firmware in echo mode.
final testDongleServices = [
  KnownService(_fbm(0x0001), 'FBM Test', test: true, [
    KnownCharacteristic(_fbm(0x0101), 'Echo', properties: {_r, _w, _wnr, _n}),
    KnownCharacteristic(_fbm(0x0102), 'Echo Indicate', properties: {_r, _w, _wnr, _i}),
    KnownCharacteristic(_fbm(0x0103), 'Long', properties: {_r, _w}),
    KnownCharacteristic(_fbm(0x0104), 'Throughput', properties: {_wnr, _n}),
    KnownCharacteristic(_fbm(0x0105), 'Status', properties: {_r, _n}),
    KnownCharacteristic(_fbm(0x0106), 'Control', properties: {_w, _n}),
    KnownCharacteristic(_fbm(0x0107), 'Encrypted', properties: {_r, _w}),
    KnownCharacteristic(_fbm(0x0108), 'Authenticated', properties: {_r, _w}),
    KnownCharacteristic(_fbm(0x0109), 'Descriptors', properties: {_r}),
    KnownCharacteristic(_fbm(0x010a), 'L2CAP Info', properties: {_r}),
    KnownCharacteristic(_fbm(0x010b), 'Counter', properties: {_r, _w, _n}),
    KnownCharacteristic(_fbm(0x010c), 'ATT Error', properties: {_r, _w}),
    // Apple's well known L2CAP PSM characteristic.
    KnownCharacteristic(Guid('abdd3056-28fa-441d-a470-55a75a52553a'), 'L2CAP PSM', properties: {_r}),
  ]),
  // Only registered after control point 0x40.
  KnownService(_fbm(0x0002), 'FBM Dynamic', test: true, [
    KnownCharacteristic(_fbm(0x0301), 'Dynamic Value', properties: {_r}),
  ]),
];

/// Bluetooth SIG services common enough to name, from the Assigned Numbers; their properties differ between
/// peripherals. Only the vendor services that are de facto standards are added.
final standardServices = [
  KnownService(Guid('1800'), 'Generic Access', [
    KnownCharacteristic(Guid('2a00'), 'Device Name'),
    KnownCharacteristic(Guid('2a01'), 'Appearance'),
    KnownCharacteristic(Guid('2a04'), 'Peripheral Preferred Connection Parameters'),
    KnownCharacteristic(Guid('2aa6'), 'Central Address Resolution'),
    KnownCharacteristic(Guid('2ac9'), 'Resolvable Private Address Only'),
  ]),
  KnownService(Guid('1801'), 'Generic Attribute', [
    KnownCharacteristic(Guid('2a05'), 'Service Changed'),
    KnownCharacteristic(Guid('2b29'), 'Client Supported Features'),
    KnownCharacteristic(Guid('2b2a'), 'Database Hash'),
    KnownCharacteristic(Guid('2b3a'), 'Server Supported Features'),
  ]),
  KnownService(Guid('180a'), 'Device Information', [
    KnownCharacteristic(Guid('2a29'), 'Manufacturer Name'),
    KnownCharacteristic(Guid('2a24'), 'Model Number'),
    KnownCharacteristic(Guid('2a25'), 'Serial Number'),
    KnownCharacteristic(Guid('2a26'), 'Firmware Revision'),
    KnownCharacteristic(Guid('2a27'), 'Hardware Revision'),
    KnownCharacteristic(Guid('2a28'), 'Software Revision'),
    KnownCharacteristic(Guid('2a23'), 'System ID'),
    KnownCharacteristic(Guid('2a50'), 'PnP ID'),
    KnownCharacteristic(Guid('2a2a'), 'IEEE 11073-20601 Regulatory Certification Data List'),
  ]),
  KnownService(Guid('180f'), 'Battery', [KnownCharacteristic(Guid('2a19'), 'Battery Level')]),
  KnownService(Guid('1802'), 'Immediate Alert', [KnownCharacteristic(Guid('2a06'), 'Alert Level')]),
  KnownService(Guid('1803'), 'Link Loss', [KnownCharacteristic(Guid('2a06'), 'Alert Level')]),
  KnownService(Guid('1804'), 'Tx Power', [KnownCharacteristic(Guid('2a07'), 'Tx Power Level')]),
  KnownService(Guid('1805'), 'Current Time', [
    KnownCharacteristic(Guid('2a2b'), 'Current Time'),
    KnownCharacteristic(Guid('2a0f'), 'Local Time Information'),
    KnownCharacteristic(Guid('2a14'), 'Reference Time Information'),
  ]),
  KnownService(Guid('1812'), 'Human Interface Device', [
    KnownCharacteristic(Guid('2a4a'), 'HID Information'),
    KnownCharacteristic(Guid('2a4b'), 'Report Map'),
    KnownCharacteristic(Guid('2a4c'), 'HID Control Point'),
    KnownCharacteristic(Guid('2a4d'), 'Report'),
    KnownCharacteristic(Guid('2a4e'), 'Protocol Mode'),
    KnownCharacteristic(Guid('2a22'), 'Boot Keyboard Input Report'),
    KnownCharacteristic(Guid('2a32'), 'Boot Keyboard Output Report'),
    KnownCharacteristic(Guid('2a33'), 'Boot Mouse Input Report'),
  ]),
  KnownService(Guid('1813'), 'Scan Parameters', [
    KnownCharacteristic(Guid('2a4f'), 'Scan Interval Window'),
    KnownCharacteristic(Guid('2a31'), 'Scan Refresh'),
  ]),
  KnownService(Guid('180d'), 'Heart Rate', [
    KnownCharacteristic(Guid('2a37'), 'Heart Rate Measurement'),
    KnownCharacteristic(Guid('2a38'), 'Body Sensor Location'),
    KnownCharacteristic(Guid('2a39'), 'Heart Rate Control Point'),
  ]),
  KnownService(Guid('1809'), 'Health Thermometer', [
    KnownCharacteristic(Guid('2a1c'), 'Temperature Measurement'),
    KnownCharacteristic(Guid('2a1d'), 'Temperature Type'),
    KnownCharacteristic(Guid('2a1e'), 'Intermediate Temperature'),
    KnownCharacteristic(Guid('2a21'), 'Measurement Interval'),
  ]),
  KnownService(Guid('1810'), 'Blood Pressure', [
    KnownCharacteristic(Guid('2a35'), 'Blood Pressure Measurement'),
    KnownCharacteristic(Guid('2a36'), 'Intermediate Cuff Pressure'),
    KnownCharacteristic(Guid('2a49'), 'Blood Pressure Feature'),
  ]),
  KnownService(Guid('1808'), 'Glucose', [
    KnownCharacteristic(Guid('2a18'), 'Glucose Measurement'),
    KnownCharacteristic(Guid('2a34'), 'Glucose Measurement Context'),
    KnownCharacteristic(Guid('2a51'), 'Glucose Feature'),
    KnownCharacteristic(Guid('2a52'), 'Record Access Control Point'),
  ]),
  KnownService(Guid('1822'), 'Pulse Oximeter', [
    KnownCharacteristic(Guid('2a5e'), 'PLX Spot-Check Measurement'),
    KnownCharacteristic(Guid('2a5f'), 'PLX Continuous Measurement'),
    KnownCharacteristic(Guid('2a60'), 'PLX Features'),
  ]),
  KnownService(Guid('181d'), 'Weight Scale', [
    KnownCharacteristic(Guid('2a9d'), 'Weight Measurement'),
    KnownCharacteristic(Guid('2a9e'), 'Weight Scale Feature'),
  ]),
  KnownService(Guid('181b'), 'Body Composition', [
    KnownCharacteristic(Guid('2a9c'), 'Body Composition Measurement'),
    KnownCharacteristic(Guid('2a9b'), 'Body Composition Feature'),
  ]),
  KnownService(Guid('181a'), 'Environmental Sensing', [
    KnownCharacteristic(Guid('2a6e'), 'Temperature'),
    KnownCharacteristic(Guid('2a6f'), 'Humidity'),
    KnownCharacteristic(Guid('2a6d'), 'Pressure'),
    KnownCharacteristic(Guid('2a6c'), 'Elevation'),
    KnownCharacteristic(Guid('2a76'), 'UV Index'),
  ]),
  KnownService(Guid('1814'), 'Running Speed and Cadence', [
    KnownCharacteristic(Guid('2a53'), 'RSC Measurement'),
    KnownCharacteristic(Guid('2a54'), 'RSC Feature'),
    KnownCharacteristic(Guid('2a5d'), 'Sensor Location'),
    KnownCharacteristic(Guid('2a55'), 'SC Control Point'),
  ]),
  KnownService(Guid('1816'), 'Cycling Speed and Cadence', [
    KnownCharacteristic(Guid('2a5b'), 'CSC Measurement'),
    KnownCharacteristic(Guid('2a5c'), 'CSC Feature'),
    KnownCharacteristic(Guid('2a5d'), 'Sensor Location'),
    KnownCharacteristic(Guid('2a55'), 'SC Control Point'),
  ]),
  KnownService(Guid('1818'), 'Cycling Power', [
    KnownCharacteristic(Guid('2a63'), 'Cycling Power Measurement'),
    KnownCharacteristic(Guid('2a65'), 'Cycling Power Feature'),
    KnownCharacteristic(Guid('2a66'), 'Cycling Power Control Point'),
    KnownCharacteristic(Guid('2a5d'), 'Sensor Location'),
  ]),
  KnownService(Guid('1826'), 'Fitness Machine', [
    KnownCharacteristic(Guid('2acc'), 'Fitness Machine Feature'),
    KnownCharacteristic(Guid('2acd'), 'Treadmill Data'),
    KnownCharacteristic(Guid('2ace'), 'Cross Trainer Data'),
    KnownCharacteristic(Guid('2ad1'), 'Rower Data'),
    KnownCharacteristic(Guid('2ad2'), 'Indoor Bike Data'),
    KnownCharacteristic(Guid('2ad3'), 'Training Status'),
    KnownCharacteristic(Guid('2ad6'), 'Supported Resistance Level Range'),
    KnownCharacteristic(Guid('2ad8'), 'Supported Power Range'),
    KnownCharacteristic(Guid('2ad9'), 'Fitness Machine Control Point'),
    KnownCharacteristic(Guid('2ada'), 'Fitness Machine Status'),
  ]),
  // Nordic UART Service: the de facto serial port over GATT on many maker and vendor boards.
  KnownService(Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e'), 'Nordic UART', [
    KnownCharacteristic(Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'), 'RX'),
    KnownCharacteristic(Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'), 'TX'),
  ]),
];
