import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_bluetooth_platform.dart';

// The plugin owns process-wide native subscriptions, just as it does in the app.
final _platform = FakeBluetoothPlatform();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('channels with the same PSM remain isolated by peer', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    final first = DeviceIdentifier('AA:BB:CC:DD:EE:01');
    final second = DeviceIdentifier('AA:BB:CC:DD:EE:02');
    platform.accepted.add(L2CapChannelConnected(remoteId: first, psm: 129));
    platform.accepted.add(L2CapChannelConnected(remoteId: second, psm: 129));
    expect(controller.channels, hasLength(2));
    platform.received.add(L2CapChannelData(remoteId: first, psm: 129, value: [1, 2, 3]));
    expect(controller.channels.first.received, 3);
    expect(controller.channels.last.received, 0);
    await controller.send(controller.channels.last, [4, 5]);
    expect(platform.writes.last.remoteId, second.str);
    expect(controller.channels.last.transmitted, 2);
    platform.closed.add(L2CapChannelClosed(remoteId: first, psm: 129));
    expect(controller.channels.single.channel.deviceId, second);
    await controller.stopServer();
    expect(controller.channels, isEmpty);
    expect(platform.closeRequests.last.remoteId, second.str);
    expect(platform.closeRequests.last.psm, 129);
    platform.accepted.add(L2CapChannelConnected(remoteId: first, psm: 129));
    expect(controller.channels, isEmpty);
  });

  test('disconnect clears peer services and channels but keeps the local server', () async {
    final (:controller, :platform) = await _setup();
    controller.select(BluetoothDevice.fromId('AA:BB:CC:DD:EE:03'));
    await controller.connect();
    await controller.discover();
    expect(controller.services, hasLength(1));
    await controller.openChannel(131, device: controller.selected!, secure: true);
    await controller.startServer(secure: true);
    platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('server'), psm: 129));
    expect(controller.channels, hasLength(2));
    await controller.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(controller.services, isEmpty);
    expect(controller.channels.single.incoming, isTrue);
    expect(controller.serverPsm, 129);
  });

  test('duplicate server submission is ignored and late startup is cleaned up on disposal', () async {
    final (:controller, :platform) = await _setup(dispose: false);
    final pending = Completer<int>();
    platform.pendingServer = pending;
    final before = platform.serverStarts;
    final opening = controller.startServer(secure: true);
    await Future<void>.delayed(Duration.zero);
    await controller.startServer(secure: false);
    expect(platform.serverStarts, before + 1);
    controller.dispose();
    pending.complete(135);
    await opening;
    platform.pendingServer = null;
    expect(platform.stoppedServers, contains(135));
    expect(controller.serverPsm, isNull);
  });

  test('failed write exposes an error, releases busy state and does not count bytes', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: false);
    platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('server'), psm: 129));
    final session = controller.channels.single;
    platform.failNextWrite = true;
    await controller.send(session, [1]);
    expect(controller.error, contains('Peer rejected'));
    expect(session.transmitted, 0);
    expect(controller.busy('channel:${session.key}'), isFalse);
    await controller.send(session, [2, 3]);
    expect(controller.error, isNull);
    expect(session.transmitted, 2);
  });

  test('adapter shutdown clears native resources and activity is bounded', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('server'), psm: 129));
    platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off));
    await Future<void>.delayed(Duration.zero);
    expect(controller.channels, isEmpty);
    expect(controller.serverPsm, isNull);
    for (var i = 0; i < WorkbenchController.maxLogEntries + 10; i++) {
      controller.log('entry $i');
    }
    expect(controller.logs, hasLength(WorkbenchController.maxLogEntries));
    expect(controller.logs.first, endsWith('entry 10'));
  });

  test('an unimplemented server reports unsupported without leaving a pending session', () async {
    final (:controller, :platform) = await _setup();
    platform.l2capFailure = UnimplementedError();
    addTearDown(() => platform.l2capFailure = null);

    await controller.startServer(secure: true);

    expect(controller.error, 'This operation is not supported on this device.');
    expect(controller.serverPsm, isNull);
    expect(controller.channels, isEmpty);
    expect(controller.busy('server'), isFalse);
    expect(controller.logs.last, contains('UnimplementedError'));
  });

  for (final failure in [
    UnimplementedError(),
    UnsupportedError('L2CAP is unavailable'),
    PlatformException(code: 'platform_not_supported', message: 'Requires Android 10 or newer.'),
  ]) {
    test('unsupported channel errors are shown without retrying: ${failure.runtimeType}', () async {
      final (:controller, :platform) = await _setup();
      final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:04');
      controller.select(peer);
      await controller.connect();
      final before = platform.openRequests.length;
      platform.l2capFailure = failure;
      addTearDown(() => platform.l2capFailure = null);

      await controller.openChannel(131, device: peer, secure: true);

      expect(platform.openRequests, hasLength(before + 1));
      expect(controller.error, 'This operation is not supported on this device.');
      expect(controller.channels, isEmpty);
      expect(controller.busy('open'), isFalse);
      expect(peer.isConnected, isTrue);
      expect(controller.logs.last, contains(failure.toString()));
    });
  }
}

Future<({WorkbenchController controller, FakeBluetoothPlatform platform})> _setup({bool dispose = true}) async {
  FlutterBlueMaxPlatform.instance = _platform;
  final controller = WorkbenchController();
  await controller.start();
  await Future<void>.delayed(Duration.zero);
  _platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on));
  await Future<void>.delayed(Duration.zero);
  if (dispose) {
    addTearDown(() async {
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
    });
  }
  return (controller: controller, platform: _platform);
}
