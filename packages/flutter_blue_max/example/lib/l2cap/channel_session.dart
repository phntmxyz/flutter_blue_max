import 'package:flutter_blue_max/flutter_blue_max.dart';

/// A channel is identified by both its remote peer and PSM.
class ChannelSession(var BluetoothL2capChannel channel, {required var bool incoming}) {
  bool closed = false;
  int transmitted = 0;
  int received = 0;
  List<int> lastReceived = [];
  final history = <ChannelReceipt>[];
  static const maxHistoryEntries = 200;

  /// Keep bounded per-channel history; buffer reads may repeat streamed data.
  void recordReceived(List<int> bytes, {required ReceiveSource source}) {
    lastReceived = List.of(bytes);
    history.insert(0, ChannelReceipt(time: DateTime.now(), source: source, bytes: List.of(bytes)));
    if (history.length > maxHistoryEntries) {
      history.removeLast();
    }
  }

  (DeviceIdentifier, int) get key => (channel.deviceId, channel.psm);
}

/// A timestamped payload displayed in a channel card's receive history.
class const ChannelReceipt({
  required final DateTime time,
  required final ReceiveSource source,
  required final List<int> bytes,
});

/// Distinguishes pushed data from buffer snapshots, which may repeat streamed bytes.
enum ReceiveSource(final String label) {
  stream('Stream'),
  bufferRead('Buffer read'),
}
