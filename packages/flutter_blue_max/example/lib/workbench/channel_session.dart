import 'package:flutter_blue_max/flutter_blue_max.dart';

/// A channel is identified by both its remote peer and PSM.
class ChannelSession {
  ChannelSession(this.channel, {required this.incoming});

  final BluetoothL2capChannel channel;
  final bool incoming;
  int transmitted = 0;
  int received = 0;
  List<int> lastReceived = [];

  (DeviceIdentifier, int) get key => (channel.deviceId, channel.psm);
}
