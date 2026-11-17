import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';

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
