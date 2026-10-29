import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_tracker.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_store.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/catalog_store.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_bluetooth_platform.dart';

// The plugin owns process-wide native subscriptions, just as it does in the app.
final _platform = FakeBluetoothPlatform();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('channels with the same PSM remain isolated by peer', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    const first = DeviceIdentifier('AA:BB:CC:DD:EE:01');
    const second = DeviceIdentifier('AA:BB:CC:DD:EE:02');
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
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('server'), psm: 129));
    expect(controller.channels, hasLength(2));
    await controller.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(controller.services, isEmpty);
    expect(controller.channels.single.incoming, isTrue);
    expect(controller.serverPsm, 129);
    final outgoing = controller.channelSessions.singleWhere((session) => !session.incoming);
    expect(outgoing.closed, isTrue, reason: 'Link loss keeps the closed session for its diagnostics');
    expect(platform.closeRequests.single.psm, 131);
  });

  test('selecting a peer keeps the channel it opened to the local server', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    const remoteId = DeviceIdentifier('AA:BB:CC:DD:EE:05');
    platform.accepted.add(L2CapChannelConnected(remoteId: remoteId, psm: 129));

    controller.select(BluetoothDevice(remoteId: remoteId));
    await Future<void>.delayed(Duration.zero);

    final session = controller.channels.single;
    expect(session.incoming, isTrue);
    platform.received.add(L2CapChannelData(remoteId: remoteId, psm: 129, value: [1, 2]));
    expect(session.received, 2);
    await controller.stopServer();
    expect(platform.closeRequests.single.remoteId, remoteId.str);
  });

  test('tracking records every advertisement of one peer and keeps the device list', () async {
    final (:controller, :platform) = await _setup();
    await controller.scan();
    platform.advertise(id: 'AA:BB:CC:DD:EE:02', name: 'Other peripheral');
    await Future<void>.delayed(Duration.zero);
    final device = BluetoothDevice.fromId('AA:BB:CC:DD:EE:01');

    await controller.trackAdvertisements(device);
    final request = platform.scanRequests.last;
    expect(request.withRemoteIds, [device.remoteId.str]);
    expect(request.continuousUpdates, isTrue);
    expect(controller.tracking, isTrue);
    platform.advertise(
      rssi: -60,
      manufacturerData: {
        0x59: [1],
      },
    );
    platform.advertise(
      rssi: -40,
      manufacturerData: {
        0x59: [1],
      },
    );
    platform.advertise(
      rssi: -50,
      manufacturerData: {
        0x59: [2],
      },
    );
    platform.advertise(id: 'AA:BB:CC:DD:EE:02', name: 'Other peripheral');
    await Future<void>.delayed(Duration.zero);

    final tracker = controller.advertisementTracker!;
    expect(tracker.count, 3, reason: 'Duplicates are recorded; other peers are not');
    expect((tracker.minRssi, tracker.maxRssi), (-60, -40));
    expect(tracker.payloadChanges, 1);
    expect(tracker.history.map((entry) => entry.changed), [true, false, true]);
    expect(describeAdvertisement(tracker.history.first.data).join('\n'), contains('Manufacturer 0x59: 02'));
    expect(tracker.averageInterval, isNotNull);
    expect(controller.scanResults.map((result) => result.device.remoteId.str), {
      'AA:BB:CC:DD:EE:01',
      'AA:BB:CC:DD:EE:02',
    });

    await controller.stopTracking();
    expect(controller.tracking, isFalse);
    expect(controller.advertisementTracker!.count, 3, reason: 'History stays available after stopping');
    await controller.scan();
    expect(platform.scanRequests.last.withRemoteIds, isEmpty);
    expect(controller.tracking, isFalse);
  });

  group('Saved parsers', () {
    test('the first launch starts with the test dongle parsers', () async {
      final (:controller, platform: _) = await _setup();
      expect(controller.parsers.map((parser) => parser.name), ['FBM status', 'FBM sensor']);
      expect(controller.error, isNull);
    });

    test('changes survive a restart, including removing every parser', () async {
      final (:controller, platform: _) = await _setup();
      for (final parser in controller.parsers.skip(1).toList()) {
        await controller.removeParser(parser);
      }
      const ruuvi = AdvertisementParser(
        name: 'Ruuvi',
        source: AdvertisementSource.manufacturer,
        companyId: 0x0499,
        device: DeviceIdentifier('AA:BB:CC:DD:EE:01'),
        fields: [AdvertisementField('Temperature', 1, AdvertisementFieldType.int16be, scale: 0.005, unit: '°C')],
      );
      await controller.saveParser(ruuvi, previous: controller.parsers.first);

      final restarted = await _setup(resetStorage: false);
      final restored = restarted.controller.parsers.single;
      expect(jsonEncode(restored), jsonEncode(ruuvi));
      expect(restored.appliesTo(const DeviceIdentifier('AA:BB:CC:DD:EE:02')), isFalse);

      await restarted.controller.removeParser(restored);
      final emptied = await _setup(resetStorage: false);
      expect(emptied.controller.parsers, isEmpty, reason: 'Deleting the examples must not bring them back');
    });

    test('own catalog services survive a restart and replace built-in ones', () async {
      final (:controller, platform: _) = await _setup();
      expect(controller.catalog, isEmpty);
      final battery = KnownService(Guid('180f'), 'Pack', test: true, [
        KnownCharacteristic(Guid('2a19'), 'Charge', properties: {GattProperty.read, GattProperty.notify}),
      ]);
      await controller.saveCatalogService(battery);
      expect(controller.knownService(Guid('180f'))?.name, 'Pack');

      final restarted = await _setup(resetStorage: false);
      expect(jsonEncode(restarted.controller.catalog.single), jsonEncode(battery));
      await restarted.controller.removeCatalogService(restarted.controller.catalog.single);
      expect(restarted.controller.knownService(Guid('180f'))?.name, 'Battery');
      final emptied = await _setup(resetStorage: false);
      expect(emptied.controller.catalog, isEmpty);
    });

    test('an unreadable stored catalog is reported instead of crashing the app', () async {
      SharedPreferences.setMockInitialValues({catalogStoreKey: '[{"name": "Broken"}]'});
      final (:controller, platform: _) = await _setup(resetStorage: false);
      expect(controller.catalog, isEmpty);
      expect(controller.error, startsWith('Loading GATT catalog'));
    });

    test('restoring the examples adds only missing ones', () async {
      final (:controller, platform: _) = await _setup();
      await controller.removeParser(controller.parsers.first);
      await controller.addExampleParsers(testDongleParsers);
      await controller.addExampleParsers(testDongleParsers);
      expect(controller.parsers, hasLength(testDongleParsers.length));
    });

    test('unreadable stored parsers are reported instead of crashing the app', () async {
      SharedPreferences.setMockInitialValues({parserStoreKey: '{"not": "a list"}'});
      final (:controller, platform: _) = await _setup(resetStorage: false);
      expect(controller.parsers, isEmpty);
      expect(controller.error, contains('parsers'));
      expect(controller.ready, isTrue);
    });
  });

  test('a failed log level still subscribes to the adapter state', () async {
    final (:controller, :platform) = await _setup(
      configure: (platform) {
        platform.overrideSetLogLevel = (_) async => throw PlatformException(code: 'bluez', message: 'No bluetoothd');
      },
    );

    expect(controller.error, contains('No bluetoothd'));
    expect(controller.ready, isTrue);
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
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('server'), psm: 129));
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
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('server'), psm: 129));
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
  group('Connection and diagnostic workflows', () {
    test('polling stops when its deadline expires', () async {
      var polls = 0;
      await expectLater(
        _until(() {
          polls++;
          return false;
        }, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      expect(polls, greaterThan(0));
      final pollsAtTimeout = polls;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(polls, pollsAtTimeout, reason: 'A timed-out poll must not keep running');
    });

    test('cancellation interrupts a pending real plugin connection without waiting for its timeout', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:51');
      c.select(peer);
      platform.holdConnections = true;
      final opening = c.connect();
      await _until(() => platform.connectRequests.any((r) => r.remoteId == peer.remoteId));
      expect(c.connectingDevice, peer);
      await c.cancelConnect().timeout(const Duration(seconds: 2));
      await opening;
      expect(c.error, isNull);
      expect(peer.isConnected, isFalse);
      expect(c.connectingDevice, isNull);
      expect(c.busy('connection'), isFalse);
    });

    test('channel open reconnects its original peer and retries once after a transient drop', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:52');
      c.select(peer);
      await c.connect();
      platform.failNextOpen = true;
      platform.disconnectOnOpenFailure = true;
      final attempts = platform.openRequests.length;
      final connections = platform.connectRequests.length;
      await c.openChannel(131, device: peer, secure: true);
      expect(c.error, isNull);
      expect(platform.openRequests.length, attempts + 2);
      expect(platform.connectRequests.length, connections + 1);
      expect(c.channels.single.channel.deviceId, peer.remoteId);
      expect(peer.isConnected, isTrue);
    });

    test('channel open does not reconnect a peer the user disconnected while opening', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:55');
      c.select(peer);
      await c.connect();
      final gate = Completer<void>();
      platform.overrideOpenL2CapChannel = (request) async {
        platform.openRequests.add(request);
        await gate.future;
        throw StateError('Temporary channel failure');
      };
      final attempts = platform.openRequests.length;
      final connections = platform.connectRequests.length;

      final opening = c.openChannel(131, device: peer, secure: true);
      await _until(() => platform.openRequests.length == attempts + 1);
      final disconnecting = c.disconnect();
      gate.complete();
      await opening;
      await disconnecting;

      expect(c.error, contains('Temporary channel failure'));
      expect(platform.openRequests.length, attempts + 1);
      expect(platform.connectRequests.length, connections);
      expect(peer.isConnected, isFalse);
      expect(c.channels, isEmpty);
    });

    test('test traffic preserves large payloads and drains the public plugin write queue', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      await c.startServer(secure: true);
      platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('traffic'), psm: 129));
      final session = c.channels.single;
      await c.sendTestTraffic(session, size: 10 * 1024, count: 1);
      final large = platform.writes.last;
      expect(large.value, hasLength(10240));
      expect(large.value.take(4), [0, 1, 2, 3]);
      expect(large.value.sublist(254, 258), [254, 255, 0, 1]);
      expect(large.value.last, 255);
      expect(large.remoteId, 'traffic');
      final gate = Completer<void>();
      platform.pendingWrites = gate;
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      final before = platform.writes.length;
      final burst = c.sendTestTraffic(session, size: 1024, count: 20);
      await _until(() => platform.writes.length == before + 1);
      expect(c.busy('channel:${session.key}'), isTrue);
      expect(session.transmitted, 10240);
      gate.complete();
      await burst;
      expect(platform.writes.length, before + 20);
      expect(platform.writes.skip(before).every((r) => r.value.length == 1024 && r.psm == 129), isTrue);
      expect(session.transmitted, 30720);
      expect(c.busy('channel:${session.key}'), isFalse);
    });

    test('a failed burst write preserves successful byte counts and releases the channel controls', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      await c.startServer(secure: true);
      platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('burst-failure'), psm: 129));
      final session = c.channels.single;
      platform.failNextWrite = true;
      await c.sendTestTraffic(session, size: 1024, count: 20);
      expect(session.transmitted, 19 * 1024);
      expect(c.error, contains('Peer rejected'));
      expect(c.busy('channel:${session.key}'), isFalse);
      expect(c.logs.any((line) => line.contains('19/20 writes')), isTrue);
    });

    test('buffer reads are per peer and preserve history without double-counting stream bytes', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      await c.startServer(secure: true);
      const peer = DeviceIdentifier('buffer');
      platform.accepted.add(L2CapChannelConnected(remoteId: peer, psm: 129));
      platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('other'), psm: 129));
      final session = c.channels.first;
      platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [65, 66]));
      platform.bufferedBytes = [65, 66];
      await c.readChannel(session);
      expect(platform.readRequests.last.remoteId, peer.str);
      expect(session.history.map((e) => e.source), ['Buffer read', 'Stream']);
      expect(session.received, 2);
      expect(c.channels.last.history, isEmpty);
      await c.readChannel(session);
      expect(session.history.first.bytes, isEmpty);
      for (var i = 0; i < ChannelSession.maxHistoryEntries + 1; i++) {
        platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [i]));
      }
      expect(session.history, hasLength(ChannelSession.maxHistoryEntries));
    });

    test('system peers can be selected and connected without receiving an advertisement', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      platform.systemPeers.add(
        BmBluetoothDevice(remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:53'), platformName: 'System peer'),
      );
      await c.scan();
      await c.scan();
      expect(platform.systemDeviceRequests.last.withServices, [Guid('180f')]);
      expect(c.systemDevices.single.platformName, 'System peer');
      c.select(c.systemDevices.single);
      await c.connect();
      await _until(() => c.rssi != null);
      expect(c.connected, isTrue);
      expect(c.rssi, -47);
      expect(c.connectedDevices, contains(c.selected));
    });

    for (final remoteClose in [true, false]) {
      test('receive history survives ${remoteClose ? 'remote' : 'local'} channel closure and reopening', () async {
        final fixture = await _setup();
        final c = fixture.controller;
        final platform = fixture.platform;
        await c.startServer(secure: false);
        const peer = DeviceIdentifier('history');
        platform.accepted.add(L2CapChannelConnected(remoteId: peer, psm: 129));
        final session = c.channels.single;
        platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [65, 66]));
        platform.bufferedBytes = [67, 68];
        await c.readChannel(session);

        if (remoteClose) {
          platform.closed.add(L2CapChannelClosed(remoteId: peer, psm: 129));
        } else {
          await c.closeChannel(session);
        }

        expect(c.channels, isEmpty);
        expect(c.channelSessions.single.closed, isTrue);
        expect(c.channelSessions.single.received, 2);
        expect(c.channelSessions.single.history.map((entry) => entry.bytes), [
          [67, 68],
          [65, 66],
        ]);
        platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [99]));
        expect(session.received, 2);

        platform.accepted.add(L2CapChannelConnected(remoteId: peer, psm: 129));
        expect(c.channels.single.closed, isFalse);
        platform.received.add(L2CapChannelData(remoteId: peer, psm: 129, value: [69]));
        expect(c.channelSessions.single.history.map((entry) => entry.bytes), [
          [69],
          [67, 68],
          [65, 66],
        ]);
        expect(session.received, 3);
        await c.stopServer();
        expect(c.channels, isEmpty);
        expect(c.channelSessions.single.history, hasLength(3));
      });
    }

    test('outgoing channels reopen after closing and retain the original 200-entry history', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:54');
      c.select(peer);
      await c.connect();
      await c.openChannel(131, device: peer, secure: false);
      for (var i = 0; i < 201; i++) {
        platform.received.add(L2CapChannelData(remoteId: peer.remoteId, psm: 131, value: [i]));
      }
      await c.closeChannel(c.channels.single);
      await c.openChannel(131, device: peer, secure: false);

      expect(c.error, isNull);
      expect(c.channels.single.history, hasLength(200));
      expect(c.channels.single.history.first.bytes, [200]);
      expect(c.channels.single.history.last.bytes, [1]);
      expect(c.channels.single.received, 201);
    });

    test('adapter turn-on uses the real library request and adapter state stream', () async {
      final fixture = await _setup();
      final c = fixture.controller;
      final platform = fixture.platform;
      platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off));
      await Future<void>.delayed(Duration.zero);
      expect(c.ready, isFalse);
      final before = platform.turnOnRequests;
      await c.turnOn();
      expect(platform.turnOnRequests, before + 1);
      await Future<void>.delayed(Duration.zero);
      expect(c.ready, isTrue);
    });
  });
}

Future<({WorkbenchController controller, FakeBluetoothPlatform platform})> _setup({
  bool dispose = true,
  bool resetStorage = true,
  void Function(FakeBluetoothPlatform platform)? configure,
}) async {
  _platform.reset();
  if (resetStorage) {
    SharedPreferences.setMockInitialValues({});
  }
  configure?.call(_platform);
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

Future<void> _until(bool Function() complete, {Duration timeout = const Duration(seconds: 2)}) async {
  final stopwatch = Stopwatch()..start();
  while (!complete()) {
    if (stopwatch.elapsed >= timeout) {
      throw TimeoutException('Condition was not met before the polling deadline', timeout);
    }
    await Future<void>.delayed(Duration.zero);
  }
}
