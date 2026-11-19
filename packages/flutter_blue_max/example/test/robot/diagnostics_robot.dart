import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max_example/gatt/gatt_characteristic.dart';
import 'package:flutter_blue_max_example/shared/payload_editor.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import '../fakes/fake_android_device.dart';
import 'workbench_robot.dart';

/// Exercises restored controls through the actual app, replacing only native I/O.
extension DiagnosticsRobot on WorkbenchRobot {
  Future<void> rejectDiagnosticClipboardWrites() async {
    final messenger = tester.binding.defaultBinaryMessenger;
    var writes = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.setData') {
        writes++;
        return Future<Object?>.error(PlatformException(code: 'clipboard_denied'));
      }
      return Future<Object?>.value();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    Future<void> tapCopyIcon(String tooltip) async {
      final icon = spot<IconButton>().withTooltip(tooltip)..existsOnce();
      await scrollIntoView(icon);
      await act.tap(icon);
      await idle();
    }

    await scanForPeripheral();
    await selectPeripheral();
    await tapCopyIcon('Copy device ID');
    expect(controller.error, contains('clipboard_denied'));

    await tapLabel('Local server');
    await controller.startServer(secure: true);
    await idle();
    await tapCopyIcon('Copy server PSM');
    expect(controller.error, contains('clipboard_denied'));

    await tapLabel('Activity');
    await tapLabel('Copy session');
    expect(writes, 3);
    expect(controller.error, contains('clipboard_denied'));
    expect(controller.logs.where((line) => line.contains('ERROR Copy to clipboard')), hasLength(3));
    spotText('Session log copied', exact: true).doesNotExist();
  }

  Future<void> inspectPeripheralWithDescriptors() async {
    platform.includeGattExtras = true;
    await inspectPeripheral();
  }

  void serveWebGatt() {
    platform.includeGattExtras = true;
    platform.emitNotifyDescriptorEvents = false;
  }

  Future<void> selectAdvertisedPeerAlsoConnectedToTheSystem() async {
    logEvent('Show the same peer in discovery and the expanded system-connected list');
    platform.systemPeers.add(
      BmBluetoothDevice(remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:01'), platformName: 'Test peripheral'),
    );
    await scanForPeripheral();
    await tapLabel('Connected to the system');
    await selectPeripheral();
    expect(controller.selected!.remoteId, const DeviceIdentifier('AA:BB:CC:DD:EE:01'));
  }

  Future<void> connectSystemPeer() async {
    logEvent('Find a system-connected peer that does not advertise');
    platform.systemPeers.add(
      BmBluetoothDevice(remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:61'), platformName: 'System peer'),
    );
    await tapLabel('Start scan');
    await tapLabel('Stop scan');
    await tapLabel('Connected to the system');
    await selectSystemPeer('System peer');
    await connectSelected();
    expect(controller.connected, isTrue);
    expect(controller.rssi, -47);
    spotText('-47 dBm', exact: true).existsOnce();
  }

  Future<void> cancelPendingConnection() async {
    logEvent('Cancel a connection while the real plugin is waiting for a native callback');
    platform.overrideConnect = (request) async {
      platform.connectRequests.add(request);
      return true;
    };
    await connectSelected();
    expect(controller.connectingDevice, controller.selected);
    await tapLabel('Cancel connection');
    expect(controller.connectingDevice, isNull);
    expect(controller.connected, isFalse);
    expect(controller.error, isNull);
    spotText('Connect', exact: true).existsOnce();
  }

  Future<void> exerciseL2capTraffic() async {
    logEvent('Send a large test payload and a concurrent burst from the channel card');
    final before = platform.writes.length;
    await tapLabel('Send 10 KB');
    expect(platform.writes.last.value, hasLength(10240));
    await tapLabel('Burst 20×1 KB');
    expect(platform.writes.length, before + 21);
    spotText('TX 30720 B', exact: true).existsOnce();
    final session = controller.channels.single;
    platform.received.add(
      L2CapChannelData(remoteId: session.channel.deviceId, psm: session.channel.psm, value: [65, 66]),
    );
    platform.bufferedBytes = [65, 66];
    await idle();
    await tapLabel('Read buffered data');
    expect(platform.readRequests.last.remoteId, session.channel.deviceId.str);
    expect(session.history, hasLength(2));
    spotText('RX 2 B', exact: true).existsOnce();
    await tapLabel('Receive history');
    spotText('Stream').existsAtLeastOnce();
    spotText('Buffer read').existsAtLeastOnce();
  }

  Future<void> requestMtuAndCreateBond() async {
    final device = FakeAndroidDevice(remoteId: controller.selected!.remoteId);
    controller.select(device);
    await idle();
    logEvent('Reject MTU values outside 23–517 and input that is no number');
    await tapLabel('Request MTU');
    final field = spot<Dialog>().spot<TextField>()..existsOnce();
    for (final input in ['22', '518', 'abc']) {
      await act.enterText(field, input);
      await tapInDialog('Request');
      spotText('Enter a value from 23 to 517.', exact: true).existsOnce();
      expect(device.mtuRequests, isEmpty);
    }
    logEvent('Cancelling sends no request');
    await tapInDialog('Cancel');
    spot<Dialog>().doesNotExist();
    expect(device.mtuRequests, isEmpty);
    for (final mtu in [23, 517]) {
      logEvent('Request boundary MTU $mtu');
      await tapLabel('Request MTU');
      await act.enterText(field, '$mtu');
      if (mtu == 23) {
        tester.view.physicalSize = const Size(390, 844);
        await idle();
      }
      await tapInDialog('Request');
      tester.view.physicalSize = const Size(1200, 850);
      await idle();
      spot<Dialog>().doesNotExist();
      expect(device.mtuRequests.last, mtu);
    }
    expect(device.mtuRequests, [23, 517]);
    expect(device.bondRequests, 0);
    await tapLabel('Create bond');
    expect(device.bondRequests, 1);
  }

  Future<void> keepWebSubscriptionUntilDisconnect() async {
    Future<void> openBatteryLevel() async {
      await tapLabel('180F');
      await tapLabel('2A19');
    }

    await openBatteryLevel();
    final pending = Completer<bool>();
    platform.overrideSetNotifyValue = (request) {
      platform.notifyRequests.add(request);
      return pending.future;
    };
    try {
      await tapLabel('Subscribe');
      expect(platform.notifyRequests.single.enable, isTrue);
      logEvent('Reopen the characteristic row before the browser confirms the subscription');
      await tapLabel('180F');
      await openBatteryLevel();
      spotText('Subscribe', exact: true).existsOnce();
    } finally {
      platform.overrideSetNotifyValue = null;
      pending.complete(false);
      await idle();
    }
    spotText('Unsubscribe', exact: true).existsOnce();
    logEvent('Select another device and come back');
    await selectPeripheral(name: 'Other peripheral');
    await selectPeripheral();
    await openBatteryLevel();
    spotText('Unsubscribe', exact: true).existsOnce();
    logEvent('A dropped link ends the browser subscription');
    await tapLabel('Disconnect');
    await connectSelected();
    await tapLabel('Discover services');
    await openBatteryLevel();
    spotText('Subscribe', exact: true).existsOnce();
    expect(platform.notifyRequests.where((r) => !r.enable), isEmpty);
  }

  Future<void> exerciseNotificationsAndDescriptors() async {
    await tapLabel('180F');
    await tapLabel('2A19');
    logEvent('Subscribe and verify the automatic read-back');
    final before = platform.characteristicReads.length;
    await tapLabel('Subscribe');
    expect(platform.notifyRequests.last.enable, isTrue);
    expect(platform.characteristicReads.length, before + 1);
    final characteristic = controller.services.single.characteristics.single;
    if (!kIsWeb) {
      expect(
        characteristic.isNotifying,
        isTrue,
        reason:
            '${characteristic.instanceId}: ${characteristic.descriptors.map((d) => '${d.uuid}/${d.instanceId}: ${d.lastValue}')}',
      );
    }
    await tapLabel('Unsubscribe');
    expect(platform.notifyRequests.last.enable, isFalse);
    expect(platform.characteristicReads.length, before + 2);
    logEvent('Write with response, then without response, and read the resulting value back');
    await tapLabel('Write');
    final payload = spot<PayloadEditor>().spot<TextField>()..existsOnce();
    await scrollIntoView(payload);
    await act.enterText(payload, '02');
    await idle();
    final readsBeforeWrite = platform.characteristicReads.length;
    await tapLabel('Write characteristic');
    expect(platform.characteristicWrites.last.writeType, BmWriteType.withResponse);
    expect(platform.characteristicReads.length, readsBeforeWrite + 1);
    await tapLabel('Without response');
    await tapLabel('Write characteristic');
    expect(platform.characteristicWrites.last.writeType, BmWriteType.withoutResponse);
    expect(platform.characteristicReads.length, readsBeforeWrite + 2);
    await tapLabel('Write');
    spot<GattDescriptorTile>().withChild(spotText('Descriptor 2901', exact: true)).existsOnce();
    await tapLabel('Descriptor 2901');
    await tapLabel('Read descriptor');
    spotText('41', exact: true).existsOnce();
    logEvent('Write an ordinary descriptor through the payload editor');
    final field = spot<PayloadEditor>().spot<TextField>()..existsOnce();
    await scrollIntoView(field);
    await act.enterText(field, '01 A2');
    await idle();
    await tapLabel('Write descriptor');
    expect(platform.descriptorWrites.last.descriptorUuid, Guid('2901'));
    expect(platform.descriptorWrites.last.value, [1, 162]);
    await tapLabel('Descriptor 2901');
    await tapLabel('Descriptor 2902');
    logEvent('The CCCD retains a direct write control as in the original example');
    spotText('Write descriptor', exact: true).existsOnce();
  }

  Future<void> inspectHistoryAfterClosing({required bool fromPeer}) async {
    logEvent('Close the channel and inspect its retained receive history');
    spotText('RX 2 B', exact: true).existsOnce();
    if (fromPeer) {
      final channel = controller.channels.single.channel;
      platform.closed.add(L2CapChannelClosed(remoteId: channel.deviceId, psm: channel.psm));
      await idle();
      spotText('Waiting for a peer — no channel connected yet.', exact: true).existsOnce();
    } else {
      await tapLabel('Close channel');
    }
    spotText('Closed', exact: true).existsOnce();
    spotText('RX 2 B', exact: true).existsOnce();
    spotText('Stream').existsAtLeastOnce();
    spotText('Buffer read').existsAtLeastOnce();
    spotText('Read buffered data', exact: true).doesNotExist();
    spotText('Send payload', exact: true).doesNotExist();
    spotText('Send 10 KB', exact: true).doesNotExist();
    spotText('Burst 20×1 KB', exact: true).doesNotExist();
  }

  void expectGattOnlyPlatform() {
    logEvent('Verify that unsupported L2CAP controls are absent');
    spotText('Local server', exact: true).doesNotExist();
    spotText('L2CAP', exact: true).doesNotExist();
    spotText('GATT explorer', exact: true).existsOnce();
    expect(controller.error, isNull);
  }

  void expectWebCapabilities() {
    expectGattOnlyPlatform();
    logEvent('Verify browser service permissions and absence of unsupported native operations');
    expect(platform.scanRequests.last.webOptionalServices, [
      Guid('180f'),
      Guid('180a'),
      Guid('1800'),
      Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e'),
    ]);
    expect(platform.rssiRequests, isEmpty);
    expect(platform.systemDeviceRequests, isEmpty);
    expect(controller.rssi, isNull);
    spotText('Read RSSI', exact: true).doesNotExist();
    spotText('Request MTU', exact: true).doesNotExist();
    spotText('Create bond', exact: true).doesNotExist();
    spotText('Advertisement', exact: true).doesNotExist();
    spotText('MTU ').doesNotExist();
  }

  Future<void> checkBroadcastAndAppearance() async {
    await tapLabel('Start scan');
    logEvent('Receive a non-connectable advertisement with an appearance value');
    platform.advertise(connectable: false, appearance: 0x0340);
    await idle();
    await tapLabel('Stop scan');
    await selectPeripheral();
    final connect = spot<FilledButton>().withChild(spotText('Connect', exact: true))..existsOnce();
    expect(connect.snapshotWidget().onPressed, isNull);
    await tapLabel('Advertisement');
    spotText('Appearance: 0x340').existsOnce();
  }

  Future<void> enableBluetooth() async {
    logEvent('Restore Bluetooth from the Android adapter banner');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off));
    await idle();
    final before = platform.turnOnRequests;
    await tapLabel('Turn on Bluetooth');
    expect(platform.turnOnRequests, before + 1);
    expect(controller.ready, isTrue);
    spotText('Turn on Bluetooth', exact: true).doesNotExist();
    debugDefaultTargetPlatformOverride = null;
  }

  Future<void> pullToRefreshDevices() async {
    logEvent('Pull down to start a fresh scan');
    final before = platform.scanStarts;
    final scanButton = spotText('Start scan', exact: true)..existsOnce();
    await scrollIntoView(scanButton);
    scanButton.existsOnce();
    await tester.drag(scanButton.finder, const Offset(0, 400));
    await idle();
    expect(platform.scanStarts, before + 1);
    await tapLabel('Stop scan');
  }
}
