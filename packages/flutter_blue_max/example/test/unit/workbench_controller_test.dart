import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_store.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/catalog_store.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_bluetooth_platform.dart';

// The plugin owns process-wide native subscriptions, just as it does in the app.
final _platform = FakeBluetoothPlatform();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dispose does not start tracking after a slow scan stop', () async {
    final (:controller, :platform) = await _setup(dispose: false);
    await controller.scan();
    await _until(() => controller.scanning);
    final release = Completer<void>();
    var stopping = false;
    platform.overrideStopScan = (_) async {
      stopping = true;
      await release.future;
      return true;
    };
    final before = platform.scanStarts;
    final pending = controller.trackAdvertisements(BluetoothDevice.fromId('AA:BB:CC:DD:EE:01'));
    await _until(() => stopping);
    controller.dispose();
    release.complete();
    await pending;
    platform.overrideStopScan = null;
    addTearDown(FlutterBlueMax.stopScan);
    expect(platform.scanStarts, before);
    expect(FlutterBlueMax.isScanningNow, isFalse);
  });

  test('dispose does not start scanning after slow system discovery', () async {
    final (:controller, :platform) = await _setup(dispose: false);
    final release = Completer<BmDevicesList>();
    var discovering = false;
    platform.overrideGetSystemDevices = (_) {
      discovering = true;
      return release.future;
    };
    final before = platform.scanStarts;
    final pending = controller.scan();
    await _until(() => discovering);
    controller.dispose();
    release.complete(BmDevicesList(devices: []));
    await pending;
    platform.overrideGetSystemDevices = null;
    addTearDown(FlutterBlueMax.stopScan);
    expect(platform.scanStarts, before);
    expect(FlutterBlueMax.isScanningNow, isFalse);
  });

  test('automatic RSSI refresh preserves the error banner while explicit reads report errors', () async {
    final (:controller, :platform) = await _setup();
    final device = BluetoothDevice.fromId('AA:BB:CC:DD:EE:57');
    controller.select(device);
    await controller.connect();
    await _until(() => controller.rssi != null);
    controller.error = 'Unread parser data';
    final before = platform.rssiRequests.length;
    controller.select(device);
    await _until(() => platform.rssiRequests.length > before);
    expect(controller.error, 'Unread parser data');
    platform.overrideReadRssi = (_) async => throw StateError('RSSI unavailable');
    controller.select(device);
    await Future<void>.delayed(Duration.zero);
    expect(controller.error, 'Unread parser data');
    expect(controller.logs.any((l) => l.contains('Automatic RSSI') && l.contains('RSSI unavailable')), isTrue);
    await controller.readRssi();
    expect(controller.error, contains('RSSI unavailable'));
  });

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
    final outgoing = controller.channelSessions.singleWhere((s) => !s.incoming);
    expect(outgoing.closed, isTrue, reason: 'Link loss keeps the closed session for its diagnostics');
    expect(platform.closeRequests.single.psm, 131);
  });

  test('a late accept from a stopped server is closed instead of orphaned', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    await controller.stopServer();
    final before = platform.closeRequests.length;
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('late'), psm: 129));
    await Future<void>.delayed(Duration.zero);
    expect(platform.closeRequests.skip(before).map((r) => r.psm), [129]);
    expect(controller.channels, isEmpty);
  });

  test('a restarted server closes provisional accepts with a different PSM', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    await controller.stopServer();
    final pending = Completer<int>();
    platform.pendingServer = pending;
    final starting = controller.startServer(secure: true);
    await Future<void>.delayed(Duration.zero);
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('stale'), psm: 129));
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('current'), psm: 131));
    pending.complete(131);
    await starting;
    platform.pendingServer = null;
    expect(controller.channels.map((s) => s.channel.psm), [131]);
    expect(platform.closeRequests.any((r) => r.remoteId == 'stale' && r.psm == 129), isTrue);
    await controller.stopServer();
    expect(controller.channels, isEmpty);
  });

  test('a failed late-accept close remains visible for a manual retry', () async {
    final (:controller, :platform) = await _setup();
    platform.overrideCloseL2CapChannel = (_) async => throw StateError('late close failed');
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('retry'), psm: 129));
    await Future<void>.delayed(Duration.zero);
    expect(controller.channels, hasLength(1));
    expect(controller.error, contains('late close failed'));
    platform.overrideCloseL2CapChannel = null;
    await controller.closeChannel(controller.channels.single);
    expect(controller.channels, isEmpty);
  });

  test('stopping the server keeps an accepted channel whose close fails open for a retry', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    const closing = DeviceIdentifier('AA:BB:CC:DD:EE:61');
    const failing = DeviceIdentifier('AA:BB:CC:DD:EE:62');
    platform.accepted.add(L2CapChannelConnected(remoteId: closing, psm: 129));
    platform.accepted.add(L2CapChannelConnected(remoteId: failing, psm: 129));
    platform.overrideCloseL2CapChannel = (r) async {
      if (r.remoteId == failing.str) {
        throw StateError('close rejected');
      }
    };

    await controller.stopServer();

    expect(controller.channels.single.channel.deviceId, failing);
    expect(controller.channelSessions.singleWhere((s) => s.channel.deviceId == closing).closed, isTrue);
    expect(controller.serverPsm, isNull);
    expect(controller.error, contains('close rejected'));
    expect(controller.busy(Operation.server), isFalse);
  });

  test('a failed channel close keeps the channel open and releases its controls', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: false);
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:63'), psm: 129));
    final session = controller.channels.single;
    platform.overrideCloseL2CapChannel = (_) async => throw StateError('close rejected');

    await controller.closeChannel(session);

    expect(session.closed, isFalse);
    expect(controller.channels, [session]);
    expect(controller.error, contains('close rejected'));
    expect(controller.busy(Operation.channel(session)), isFalse);
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
      const climate = AdvertisementParser(
        name: 'Climate',
        source: AdvertisementSource.manufacturer,
        companyId: 0xffff,
        device: DeviceIdentifier('AA:BB:CC:DD:EE:01'),
        fields: [AdvertisementField('Temperature', 1, AdvertisementFieldType.int16be, scale: 0.005, unit: '°C')],
      );
      await controller.saveParser(climate, previous: controller.parsers.first);

      final restarted = await _setup(resetStorage: false);
      final restored = restarted.controller.parsers.single;
      expect(jsonEncode(restored), jsonEncode(climate));
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

    test('adding catalog services replaces own entries with the same UUID and skips identical ones', () async {
      final (:controller, platform: _) = await _setup();
      final thermostat = KnownService(Guid('fff0'), 'Thermostat', [KnownCharacteristic(Guid('fff1'), 'Level')]);
      final renamed = KnownService(Guid('fff0'), 'Room thermostat', thermostat.characteristics);
      final lamp = KnownService(Guid('ffe0'), 'Lamp', []);
      final first = await controller.addCatalogServices([thermostat]);
      expect([first.added, first.replaced, first.present], [1, 0, 0]);
      final next = await controller.addCatalogServices([renamed, lamp, lamp]);
      expect([next.added, next.replaced, next.present], [1, 1, 1]);
      expect(controller.catalog.map((s) => s.name), ['Room thermostat', 'Lamp']);
    });

    test('a catalog reset repairs an unreadable stored catalog', () async {
      SharedPreferences.setMockInitialValues({catalogStoreKey: '[{"name": "Broken"}]'});
      final (:controller, platform: _) = await _setup(resetStorage: false);
      expect(controller.error, startsWith('Loading GATT catalog'));
      await controller.resetCatalog();
      final stored = await loadCatalog();
      expect(stored?.items, isEmpty);
      expect(stored?.unreadable, isEmpty);
    });

    test('restoring the examples adds only missing ones', () async {
      final (:controller, platform: _) = await _setup();
      await controller.removeParser(controller.parsers.first);
      await controller.addParsers(testDongleParsers);
      await controller.addParsers(testDongleParsers);
      expect(controller.parsers, hasLength(testDongleParsers.length));
    });

    test('adding parsers skips present ones and reports how many were added', () async {
      final (:controller, platform: _) = await _setup();
      const own = AdvertisementParser(
        name: 'Own',
        source: AdvertisementSource.manufacturer,
        companyId: 0x1234,
        fields: [],
      );
      expect(await controller.addParsers([testDongleParsers.first, own, own]), 1);
      expect(controller.parsers.map((parser) => parser.name), [...testDongleParsers.map((p) => p.name), 'Own']);
    });

    test('a reset repairs unreadable stored parsers', () async {
      SharedPreferences.setMockInitialValues({parserStoreKey: '[{"name": "Broken"}]'});
      final (:controller, platform: _) = await _setup(resetStorage: false);
      expect(controller.parsers, isEmpty);
      await controller.resetParsers();
      expect(jsonEncode(controller.parsers), jsonEncode(testDongleParsers));
      final stored = await loadParsers();
      expect(jsonEncode(stored?.items), jsonEncode(testDongleParsers));
      expect(stored?.unreadable, isEmpty);
    });

    test('a stored entry that no longer decodes survives saving the readable ones', () async {
      final own = KnownService(Guid('fff0'), 'Own', []);
      const broken = {'name': 'Broken'};
      SharedPreferences.setMockInitialValues({
        catalogStoreKey: jsonEncode([own, broken]),
        parserStoreKey: jsonEncode([testDongleParsers.first, broken]),
      });
      final (:controller, platform: _) = await _setup(resetStorage: false);
      expect(controller.catalog.single.name, 'Own');
      expect(controller.parsers.single.name, testDongleParsers.first.name);
      expect(controller.error, contains('1 stored entry could not be read'));

      await controller.saveCatalogService(KnownService(Guid('ffe0'), 'Lamp', []));
      await controller.removeParser(controller.parsers.single);
      final catalog = await loadCatalog();
      expect(catalog?.items.map((s) => s.name), ['Own', 'Lamp']);
      expect(catalog?.unreadable, [broken]);
      final parsers = await loadParsers();
      expect(parsers?.items, isEmpty);
      expect(parsers?.unreadable, [broken]);
    });

    test('a store that is not a list is never overwritten by an ordinary save', () async {
      SharedPreferences.setMockInitialValues({catalogStoreKey: '{"not": "a list"}'});
      final (:controller, platform: _) = await _setup(resetStorage: false);
      await controller.saveCatalogService(KnownService(Guid('ffe0'), 'Lamp', []));
      expect(controller.error, contains('changes are not saved'));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(catalogStoreKey), '{"not": "a list"}');

      await controller.resetCatalog();
      expect((await loadCatalog())?.items, isEmpty);
    });

    test('a failed save is reported and later saves still run', () async {
      var fail = true;
      final saved = <String, List<Object?>>{};
      final (:controller, platform: _) = await _setup(
        saveList: (key, items, {unreadable = const []}) async {
          if (fail) {
            throw StateError('disk full');
          }
          saved[key] = items;
        },
      );

      await controller.removeParser(controller.parsers.first);
      expect(controller.error, 'Saving parsers: Bad state: disk full');
      expect(controller.logs.last, contains('ERROR saving parsers'));

      fail = false;
      await controller.saveCatalogService(KnownService(Guid('ffe0'), 'Lamp', []));
      expect(saved[catalogStoreKey], hasLength(1));
    });

    test('a slow save never overwrites a newer one', () async {
      final slow = Completer<void>();
      final saved = <List<Object?>>[];
      var saves = 0;
      final (:controller, platform: _) = await _setup(
        saveList: (key, items, {unreadable = const []}) async {
          if (saves++ == 0) {
            await slow.future;
          }
          saved.add(items);
        },
      );

      final first = controller.removeParser(controller.parsers.first);
      final second = controller.removeParser(controller.parsers.first);
      slow.complete();
      await Future.wait([first, second]);

      expect(saved.map((items) => items.length), [1, 0]);
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
      configure: (it) {
        it.overrideSetLogLevel = (_) async => throw PlatformException(code: 'bluez', message: 'No bluetoothd');
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

  test('a peer accepted before the server reports its PSM is kept', () async {
    final (:controller, :platform) = await _setup();
    final pending = Completer<int>();
    platform.pendingServer = pending;
    final starting = controller.startServer(secure: true);
    await Future<void>.delayed(Duration.zero);

    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('early'), psm: 135));
    pending.complete(135);
    await starting;

    expect(controller.serverPsm, 135);
    expect(controller.channels.single.incoming, isTrue);
    expect(controller.channels.single.channel.deviceId, const DeviceIdentifier('early'));
  });

  test('disposal stops the scan, closes channels, stops the server and disconnects peers', () async {
    final (:controller, :platform) = await _setup(dispose: false);
    final peer = BluetoothDevice.fromId('AA:BB:CC:DD:EE:07');
    controller.select(peer);
    await controller.connect();
    await controller.openChannel(131, device: peer, secure: true);
    await controller.startServer(secure: true);
    await controller.scan();
    expect(controller.scanning, isTrue);
    final stops = platform.scanStops;

    controller.dispose();
    await _until(() => platform.connected.isEmpty);

    expect(platform.scanStops, stops + 1);
    expect(platform.closeRequests.single.psm, 131);
    expect(platform.stoppedServers, [129]);
    expect(peer.isConnected, isFalse);
  });

  test('failed write exposes an error, releases busy state and does not count bytes', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: false);
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('server'), psm: 129));
    final session = controller.channels.single;
    platform.failNextWrite = true;
    await controller.send(session, [1]);
    expect(controller.error, 'L2CAP channel: Bad state: Peer rejected the write');
    expect(session.transmitted, 0);
    expect(controller.busy(Operation.channel(session)), isFalse);
    await controller.send(session, [2, 3]);
    expect(controller.error, isNull);
    expect(session.transmitted, 2);
  });

  test('adapter shutdown clears native resources and activity is bounded', () async {
    final (:controller, :platform) = await _setup();
    await controller.startServer(secure: true);
    platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('server'), psm: 129));
    platform.received.add(L2CapChannelData(remoteId: const DeviceIdentifier('server'), psm: 129, value: [1, 2]));
    platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off));
    await Future<void>.delayed(Duration.zero);
    expect(controller.channels, isEmpty);
    expect(controller.serverPsm, isNull);
    final session = controller.channelSessions.single;
    expect(session.closed, isTrue, reason: 'Adapter loss keeps the closed session for its diagnostics');
    expect(session.received, 2);
    expect(session.history.single.bytes, [1, 2]);
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
    expect(controller.busy(Operation.server), isFalse);
    expect(controller.logs.last, contains('UnimplementedError'));
  });

  test('an unsupported error outside a plugin call is reported with its message', () async {
    final (:controller, platform: _) = await _setup();

    await controller.run(Operation.bond, () async => controller.catalog.clear());

    expect(controller.error, startsWith('Bond: Unsupported operation'));
  });

  test('the server reports unsupported on a platform without L2CAP', () async {
    final (:controller, :platform) = await _setup();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await controller.startServer(secure: true);

    expect(controller.error, 'This operation is not supported on this device.');
    expect(platform.listenRequests, isEmpty);
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
      expect(controller.busy(Operation.open), isFalse);
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
      expect(c.busy(Operation.connection), isFalse);
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
      platform.overrideOpenL2CapChannel = (r) async {
        platform.openRequests.add(r);
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
      expect(c.busy(Operation.channel(session)), isTrue);
      expect(session.transmitted, 10240);
      gate.complete();
      await burst;
      expect(platform.writes.length, before + 20);
      expect(platform.writes.skip(before).every((r) => r.value.length == 1024 && r.psm == 129), isTrue);
      expect(session.transmitted, 30720);
      expect(c.busy(Operation.channel(session)), isFalse);
    });

    test('burst listeners see successful bytes before the final write completes', () async {
      final (:controller, :platform) = await _setup();
      await controller.startServer(secure: true);
      platform.accepted.add(L2CapChannelConnected(remoteId: const DeviceIdentifier('progress'), psm: 129));
      final session = controller.channels.single;
      final release = Completer<void>();
      var writes = 0;
      platform.overrideWriteL2CapChannel = (_) async {
        if (++writes == 2) {
          await release.future;
        }
      };
      final observed = <int>[];
      controller.addListener(() => observed.add(session.transmitted));
      final pending = controller.sendTestTraffic(session, size: 1024, count: 2);
      await _until(() => writes == 2 && session.transmitted == 1024);
      try {
        expect(controller.busy(Operation.channel(session)), isTrue);
        expect(observed, contains(1024));
      } finally {
        release.complete();
        await pending;
      }
      expect(session.transmitted, 2048);
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
      expect(c.busy(Operation.channel(session)), isFalse);
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
      expect(session.history.map((e) => e.source), [ReceiveSource.bufferRead, ReceiveSource.stream]);
      expect(session.received, 2);
      expect(c.channels.last.history, isEmpty);
      await c.readChannel(session);
      expect(session.history.map((e) => e.source), [
        ReceiveSource.bufferRead,
        ReceiveSource.stream,
      ], reason: 'An empty read adds no entry');
      expect(session.lastReceived, [65, 66]);
      expect(c.logs.last, endsWith(': 0 B'));
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
  Future<void> Function(String key, List<Object?> items, {List<Object?> unreadable}) saveList = saveStoredList,
}) async {
  _platform.reset();
  if (resetStorage) {
    SharedPreferences.setMockInitialValues({});
  }
  configure?.call(_platform);
  FlutterBlueMaxPlatform.instance = _platform;
  final controller = WorkbenchController(saveList: saveList);
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
