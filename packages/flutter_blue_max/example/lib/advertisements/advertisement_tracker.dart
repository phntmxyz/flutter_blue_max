import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter_blue_max/flutter_blue_max.dart";

/// Follows every advertisement of one peer, including duplicates the device list collapses.
class AdvertisementTracker(final DeviceIdentifier remoteId) {
  final _history = <AdvertisementHistoryEntry>[];
  static const maxHistoryEntries = 200;

  /// Raw data is kept so parsers added later also apply to earlier advertisements.
  List<AdvertisementHistoryEntry> get history => List.unmodifiable(_history);

  /// Totals cover the whole session, beyond the bounded history.
  int get count => _count;
  int get payloadChanges => _payloadChanges;
  int? get minRssi => _minRssi;
  int? get maxRssi => _maxRssi;

  int _count = 0;
  int _payloadChanges = 0;
  int? _minRssi;
  int? _maxRssi;
  DateTime? _first;

  void record(ScanResult result) {
    final data = result.advertisementData;
    final previous = _history.firstOrNull;
    // The first advertisement is the baseline: a change for filtering, but excluded from the count.
    final changed = previous == null || !_sameAdvertisement(previous.data, data);
    _count++;
    if (changed && previous != null) {
      _payloadChanges++;
    }
    _first ??= result.timeStamp;
    _minRssi = min(_minRssi ?? result.rssi, result.rssi);
    _maxRssi = max(_maxRssi ?? result.rssi, result.rssi);
    _history.insert(
      0,
      AdvertisementHistoryEntry(
        time: result.timeStamp,
        rssi: result.rssi,
        interval: previous == null ? null : result.timeStamp.difference(previous.time),
        data: data,
        changed: changed,
      ),
    );
    if (_history.length > maxHistoryEntries) {
      _history.removeLast();
    }
  }

  Duration? get averageInterval {
    final first = _first;
    final last = _history.firstOrNull?.time;
    if (first == null || last == null || count < 2) {
      return null;
    }
    return last.difference(first) ~/ (count - 1);
  }
}

/// An immutable tracked sample and its relationship to the preceding sample.
class AdvertisementHistoryEntry({
  required final DateTime time,
  required final int rssi,
  required final Duration? interval,
  required AdvertisementData data,
  required final bool changed,
}) {
  final AdvertisementData data = _captureAdvertisement(data);
}

AdvertisementData _captureAdvertisement(AdvertisementData data) => AdvertisementData(
  advName: data.advName,
  txPowerLevel: data.txPowerLevel,
  appearance: data.appearance,
  connectable: data.connectable,
  manufacturerData: Map.unmodifiable({
    for (final entry in data.manufacturerData.entries) entry.key: List<int>.unmodifiable(entry.value),
  }),
  serviceData: Map.unmodifiable({
    for (final entry in data.serviceData.entries) _freezeGuid(entry.key): List<int>.unmodifiable(entry.value),
  }),
  serviceUuids: List.unmodifiable(data.serviceUuids.map(_freezeGuid)),
);

Guid _freezeGuid(Guid uuid) => Guid.fromBytes(List.unmodifiable(uuid.bytes));

bool _sameAdvertisement(AdvertisementData first, AdvertisementData second) =>
    first.advName == second.advName &&
    first.txPowerLevel == second.txPowerLevel &&
    first.appearance == second.appearance &&
    first.connectable == second.connectable &&
    listEquals(first.serviceUuids, second.serviceUuids) &&
    _samePayloads(first.manufacturerData, second.manufacturerData) &&
    _samePayloads(first.serviceData, second.serviceData);

bool _samePayloads<K>(Map<K, List<int>> first, Map<K, List<int>> second) =>
    first.length == second.length && first.entries.every((entry) => listEquals(entry.value, second[entry.key]));
