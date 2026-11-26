import "package:clock/clock.dart";
import "package:flutter_blue_max/flutter_blue_max.dart";
import "package:flutter_blue_max_example/app/workbench_controller.dart";
import "package:flutter_blue_max_example/l2cap/channel_session.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  final time = DateTime.utc(2030, 1, 2, 3, 4, 5);
  test("activity timestamps use the scoped clock", () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);
    withClock(Clock.fixed(time), () => controller.log("clock test"));
    expect(controller.logs.single, "${time.toIso8601String()}  clock test");
  });
  test("activity severity is independent of log content", () async {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    controller.log("ERROR sensor connected");
    await controller.run(Operation.connection, () => Future<void>.error(StateError("lost connection")));

    expect(controller.activity.value.map((entry) => entry.severity), [ActivitySeverity.info, ActivitySeverity.error]);
    expect(controller.logs.first, endsWith("ERROR sensor connected"));
  });

  test("channel receipt timestamps use the scoped clock", () {
    final channel = BluetoothL2capChannel(deviceId: const DeviceIdentifier("clock"), psm: 129);
    final session = ChannelSession(channel, incoming: true);
    final payload = [1];
    withClock(Clock.fixed(time), () => session.onStreamed(payload));
    final first = session.history;
    payload[0] = 2;
    expect(first.single.time, time);
    expect(first.single.bytes, [1]);
    expect(first.single.bytes.clear, throwsUnsupportedError);
    expect(session.history, same(first));
    session.onStreamed(payload);
    expect(first, hasLength(1));
    expect(session.history, hasLength(2));
  });
}
