import 'package:clock/clock.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime.utc(2030, 1, 2, 3, 4, 5);
  test('activity timestamps use the scoped clock', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);
    withClock(Clock.fixed(time), () => controller.log('clock test'));
    expect(controller.logs.single, '${time.toIso8601String()}  clock test');
  });
  test('channel receipt timestamps use the scoped clock', () {
    final channel = BluetoothL2capChannel(deviceId: const DeviceIdentifier('clock'), psm: 129);
    final session = ChannelSession(channel, incoming: true);
    withClock(Clock.fixed(time), () => session.onStreamed([1]));
    expect(session.history.single.time, time);
  });
}
