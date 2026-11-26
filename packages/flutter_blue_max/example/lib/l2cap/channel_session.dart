import "package:clock/clock.dart";
import "package:flutter_blue_max/flutter_blue_max.dart";
import "package:flutter_blue_max_example/shared/payload_codec.dart";

/// UI state for one L2CAP channel, retained by the workbench controller.
/// Reopening the same remote peer, PSM and direction reuses this session, so
/// byte totals and [history] accumulate until the workbench is disposed.
class ChannelSession(var BluetoothL2capChannel _channel, {required final bool incoming}) {
  bool _closed = false;
  int _transmitted = 0;
  int _received = 0;
  List<ChannelReceipt> _history = const [];
  static const maxHistoryEntries = 200;

  BluetoothL2capChannel get channel => _channel;

  /// Retained after closure so the UI can still inspect receipts and totals.
  bool get closed => _closed;

  /// Bytes whose writes completed successfully across all openings.
  int get transmitted => _transmitted;

  /// Streamed bytes only; buffer snapshots may repeat them and do not count twice.
  int get received => _received;
  List<int> get lastReceived => _history.firstOrNull?.bytes ?? const [];
  List<ChannelReceipt> get history => _history;

  void markClosed() => _closed = true;

  /// Replaces the native handle without losing diagnostics from earlier openings.
  void reopen(BluetoothL2capChannel channel) {
    _channel = channel;
    _closed = false;
  }

  /// Called only after the native write completes successfully.
  void onTransmitted(List<int> bytes) => _transmitted += bytes.length;

  void onStreamed(List<int> bytes) {
    _received += bytes.length;
    _record(bytes, source: ReceiveSource.stream);
  }

  /// Empty buffer reads leave the most recent payload and history intact.
  void onBufferRead(List<int> bytes) {
    if (bytes.isEmpty) {
      return;
    }
    _record(bytes, source: ReceiveSource.bufferRead);
  }

  void _record(List<int> bytes, {required ReceiveSource source}) {
    final receipt = ChannelReceipt(time: clock.now(), source: source, payload: bytes);
    _history = List.unmodifiable([receipt, ..._history.take(maxHistoryEntries - 1)]);
  }

  (DeviceIdentifier, int, bool) get key => (channel.deviceId, channel.psm, incoming);
}

/// A timestamped payload displayed in a channel card's receive history.
class ChannelReceipt({required final DateTime time, required final ReceiveSource source, required List<int> payload}) {
  final List<int> bytes = List.unmodifiable(payload);
  late final String hex = PayloadCodec.hex(bytes);
  late final String text = PayloadCodec.text(bytes);
}

/// Distinguishes pushed data from buffer snapshots, which may repeat streamed bytes.
enum ReceiveSource(final String label) {
  stream("Stream"),
  bufferRead("Buffer read"),
}
