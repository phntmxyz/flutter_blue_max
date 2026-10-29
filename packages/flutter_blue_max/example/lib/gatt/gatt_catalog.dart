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

KnownService? knownService(Guid uuid) {
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

/// Bluetooth SIG services common enough to name; their properties differ between peripherals.
final standardServices = [
  KnownService(Guid('1800'), 'Generic Access', [
    KnownCharacteristic(Guid('2a00'), 'Device Name'),
    KnownCharacteristic(Guid('2a01'), 'Appearance'),
    KnownCharacteristic(Guid('2a04'), 'Peripheral Preferred Connection Parameters'),
    KnownCharacteristic(Guid('2aa6'), 'Central Address Resolution'),
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
  ]),
  KnownService(Guid('180f'), 'Battery', [KnownCharacteristic(Guid('2a19'), 'Battery Level')]),
];
