import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';

/// Human-readable advertisement fields; without parsers also the identity used to detect payload changes.
/// Parsed values follow the payload they were read from.
List<String> describeAdvertisement(AdvertisementData data, {List<AdvertisementParser> parsers = const []}) => [
  'Name: ${data.advName}',
  if (data.txPowerLevel != null) 'TX power: ${data.txPowerLevel} dBm',
  if (data.appearance != null) 'Appearance: 0x${data.appearance!.toRadixString(16)}',
  for (final uuid in data.serviceUuids) 'Service: $uuid',
  for (final entry in data.manufacturerData.entries) ...[
    'Manufacturer 0x${entry.key.toRadixString(16)}: ${PayloadCodec.hex(entry.value)}',
    for (final parser in parsers)
      for (final line in parser.read(companyId: entry.key, bytes: entry.value)) '  ↳ $line',
  ],
  for (final entry in data.serviceData.entries) ...[
    'Service data ${entry.key}: ${PayloadCodec.hex(entry.value)}',
    for (final parser in parsers)
      for (final line in parser.read(serviceUuid: entry.key, bytes: entry.value)) '  ↳ $line',
  ],
];

/// Only the values the parsers read, for compact history rows.
List<String> parsedValues(AdvertisementData data, List<AdvertisementParser> parsers) => [
  for (final parser in parsers) ...[
    for (final entry in data.manufacturerData.entries) ...parser.read(companyId: entry.key, bytes: entry.value),
    for (final entry in data.serviceData.entries) ...parser.read(serviceUuid: entry.key, bytes: entry.value),
  ],
];

/// Follows every advertisement of one peer, including duplicates the device list collapses.
class AdvertisementTracker(final DeviceIdentifier remoteId) {
  /// Raw data is kept so parsers added later also apply to earlier advertisements.
  final List<({DateTime time, int rssi, Duration? interval, AdvertisementData data, bool changed})> history = [];
  static const maxHistoryEntries = 200;

  /// Totals cover the whole session, not only the bounded history.
  int count = 0;
  int payloadChanges = 0;
  int? minRssi;
  int? maxRssi;
  DateTime? _first;
  DateTime? _last;
  String? _payload;

  void record(ScanResult result) {
    final payload = describeAdvertisement(result.advertisementData).join('\n');
    final previous = _last;
    // The first advertisement is the baseline: a change for filtering, but not counted as one.
    final changed = _payload != payload;
    count++;
    if (changed && _payload != null) {
      payloadChanges++;
    }
    _first ??= result.timeStamp;
    _last = result.timeStamp;
    _payload = payload;
    minRssi = minRssi == null || result.rssi < minRssi! ? result.rssi : minRssi;
    maxRssi = maxRssi == null || result.rssi > maxRssi! ? result.rssi : maxRssi;
    history.insert(0, (
      time: result.timeStamp,
      rssi: result.rssi,
      interval: previous == null ? null : result.timeStamp.difference(previous),
      data: result.advertisementData,
      changed: changed,
    ));
    if (history.length > maxHistoryEntries) {
      history.removeLast();
    }
  }

  Duration? get averageInterval {
    final first = _first;
    final last = _last;
    if (first == null || last == null || count < 2) {
      return null;
    }
    return last.difference(first) ~/ (count - 1);
  }
}
