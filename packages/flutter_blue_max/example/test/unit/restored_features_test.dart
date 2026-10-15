import 'dart:async';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_bluetooth_platform.dart';

final _platform = FakeBluetoothPlatform();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancellation interrupts a pending real plugin connection without waiting for its timeout', () async {
    final c = await _setup();
    final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:51');
    c.select(peer);
    _platform.holdConnections = true;
    final opening = c.connect();
    await _until(() => _platform.connectRequests.any((r) => r.remoteId == peer.remoteId));
    expect(c.connectingDevice, peer);
    await c.cancelConnect().timeout(const Duration(seconds: 2));
    await opening;
    expect(c.error, isNull);
    expect(peer.isConnected, isFalse);
    expect(c.connectingDevice, isNull);
    expect(c.busy('connection'), isFalse);
  });

  test('channel open reconnects its original peer and retries once after a transient drop', () async {
    final c = await _setup();
    final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:52');
    c.select(peer);
    await c.connect();
    _platform.failNextOpen = true;
    _platform.disconnectOnOpenFailure = true;
    final attempts = _platform.openRequests.length;
    final connections = _platform.connectRequests.length;
    await c.openChannel(131, device: peer, secure: true);
    expect(c.error, isNull);
    expect(_platform.openRequests.length, attempts + 2);
    expect(_platform.connectRequests.length, connections + 1);
    expect(c.channels.single.channel.deviceId, peer.remoteId);
    expect(peer.isConnected, isTrue);
  });

  test('test traffic preserves large payloads and drains the public plugin write queue', () async {
    final c = await _setup();
    await c.startServer(secure: true);
    _platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('traffic'), psm: 129));
    final session = c.channels.single;
    await c.sendTestTraffic(session, size: 10 * 1024, count: 1);
    final large = _platform.writes.last;
    expect(large.value, hasLength(10240));
    expect(large.value.take(4), [0, 1, 2, 3]);
    expect(large.value.sublist(254, 258), [254, 255, 0, 1]);
    expect(large.value.last, 255);
    expect(large.remoteId, 'traffic');
    final gate = Completer<void>();
    _platform.pendingWrites = gate;
    addTearDown(() {
      if (!gate.isCompleted) {
        gate.complete();
      }
    });
    final before = _platform.writes.length;
    final burst = c.sendTestTraffic(session, size: 1024, count: 20);
    await _until(() => _platform.writes.length == before + 1);
    expect(c.busy('channel:${session.key}'), isTrue);
    expect(session.transmitted, 10240);
    gate.complete();
    await burst;
    expect(_platform.writes.length, before + 20);
    expect(_platform.writes.skip(before).every((r) => r.value.length == 1024 && r.psm == 129), isTrue);
    expect(session.transmitted, 30720);
    expect(c.busy('channel:${session.key}'), isFalse);
  });

  test('a failed burst write preserves successful byte counts and releases the channel controls', () async {
    final c = await _setup();
    await c.startServer(secure: true);
    _platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('burst-failure'), psm: 129));
    final session = c.channels.single;
    _platform.failNextWrite = true;
    await c.sendTestTraffic(session, size: 1024, count: 20);
    expect(session.transmitted, 19 * 1024);
    expect(c.error, contains('Peer rejected'));
    expect(c.busy('channel:${session.key}'), isFalse);
    expect(c.logs.any((line) => line.contains('19/20 writes')), isTrue);
  });

  test('buffer reads are per peer and preserve history without double-counting stream bytes', () async {
    final c = await _setup();
    await c.startServer(secure: true);
    final peer = DeviceIdentifier('buffer');
    _platform.accepted.add(L2CapChannelConnected(remoteId: peer, psm: 129));
    _platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('other'), psm: 129));
    final session = c.channels.first;
    _platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [65, 66]));
    _platform.bufferedBytes = [65, 66];
    await c.readChannel(session);
    expect(_platform.readRequests.last.remoteId, peer.str);
    expect(session.history.map((e) => e.source), ['Buffer read', 'Stream']);
    expect(session.received, 2);
    expect(c.channels.last.history, isEmpty);
    await c.readChannel(session);
    expect(session.history.first.bytes, isEmpty);
    for (var i = 0; i < ChannelSession.maxHistoryEntries + 1; i++) {
      _platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [i]));
    }
    expect(session.history, hasLength(ChannelSession.maxHistoryEntries));
  });

  test('system peers can be selected and connected without receiving an advertisement', () async {
    final c = await _setup();
    _platform.systemPeers.add(
      BmBluetoothDevice(remoteId: DeviceIdentifier('AA:BB:CC:DD:EE:53'), platformName: 'System peer'),
    );
    await c.scan();
    await c.scan();
    expect(_platform.systemDeviceRequests.last.withServices, [Guid('180f')]);
    expect(c.systemDevices.single.platformName, 'System peer');
    c.select(c.systemDevices.single);
    await c.connect();
    await _until(() => c.rssi != null);
    expect(c.connected, isTrue);
    expect(c.rssi, -47);
    expect(c.connectedDevices, contains(c.selected));
  });

  test('adapter turn-on uses the real library request and adapter state stream', () async {
    final c = await _setup();
    _platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off));
    await Future<void>.delayed(Duration.zero);
    expect(c.ready, isFalse);
    final before = _platform.turnOnRequests;
    await c.turnOn();
    expect(_platform.turnOnRequests, before + 1);
    await Future<void>.delayed(Duration.zero);
    expect(c.ready, isTrue);
  });
}

Future<WorkbenchController> _setup() async {
  FlutterBlueMaxPlatform.instance = _platform;
  _platform.holdConnections = false;
  _platform.pendingWrites = null;
  _platform.failNextOpen = false;
  _platform.disconnectOnOpenFailure = false;
  _platform.systemPeers.clear();
  final c = WorkbenchController();
  await c.start();
  await Future<void>.delayed(Duration.zero);
  _platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on));
  addTearDown(() async {
    _platform.holdConnections = false;
    _platform.pendingWrites = null;
    c.dispose();
    await Future<void>.delayed(Duration.zero);
  });
  return c;
}

Future<void> _until(bool Function() complete) async {
  await Future<void>(() async {
    while (!complete()) {
      await Future<void>.delayed(Duration.zero);
    }
  }).timeout(const Duration(seconds: 2));
}
