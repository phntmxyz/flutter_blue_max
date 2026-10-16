import 'package:flutter_blue_max/flutter_blue_max.dart';

/// A channel is identified by both its remote peer and PSM.
class ChannelSession {
  ChannelSession(this.channel, {required this.incoming});

  final BluetoothL2capChannel channel;
  final bool incoming;
  int transmitted = 0;
  int received = 0;
  List<int> lastReceived = [];
  final List<({DateTime time, String source, List<int> bytes})> history = [];
  static const maxHistoryEntries = 100;

  /// Keep bounded per-channel history; buffer reads may repeat streamed data.
  void recordReceived(List<int> bytes, {required String source}) {
    lastReceived = List.of(bytes);
    history.insert(0, (time: DateTime.now(), source: source, bytes: List.of(bytes)));
    if (history.length > maxHistoryEntries) {
      history.removeLast();
    }
  }

  (DeviceIdentifier, int) get key => (channel.deviceId, channel.psm);
}
