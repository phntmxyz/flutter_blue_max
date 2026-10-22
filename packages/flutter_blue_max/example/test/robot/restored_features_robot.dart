import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import 'workbench_robot.dart';

/// Exercises restored controls through the actual app, replacing only native I/O.
extension RestoredFeaturesRobot on WorkbenchRobot {
  Future<void> connectSystemPeer() async {
    logEvent('Find a system-connected peer that does not advertise');
    platform.systemPeers.add(
      BmBluetoothDevice(remoteId: DeviceIdentifier('AA:BB:CC:DD:EE:61'), platformName: 'System peer'),
    );
    await tapLabel('Start scan');
    await tapLabel('Stop scan');
    await tapLabel('Connected to the system');
    await selectPeripheral(name: 'System peer');
    await connectSelected();
    expect(controller.connected, isTrue);
    expect(controller.rssi, -47);
    spotText('-47 dBm', exact: true).existsOnce();
  }

  Future<void> cancelPendingConnection() async {
    logEvent('Cancel a connection while the real plugin is waiting for a native callback');
    platform.holdConnections = true;
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
    spotText('Stream', exact: false).existsAtLeastOnce();
    spotText('Buffer read', exact: false).existsAtLeastOnce();
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
    final payload = spot<TextFormField>()..existsOnce();
    await tester.ensureVisible(find.byType(TextFormField));
    await idle();
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
    await tapLabel('Descriptor 2901');
    await tapLabel('Read descriptor');
    spotText('41', exact: true).existsOnce();
    logEvent('Write an ordinary descriptor through the payload editor');
    final field = spot<TextFormField>()..existsOnce();
    await tester.ensureVisible(find.byType(TextFormField));
    await idle();
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
    spotText('Stream', exact: false).existsAtLeastOnce();
    spotText('Buffer read', exact: false).existsAtLeastOnce();
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
    spotText('MTU ', exact: false).doesNotExist();
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
    spotText('Appearance: 0x340', exact: false).existsOnce();
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
    await tester.ensureVisible(find.text('Start scan'));
    scanButton.existsOnce();
    await tester.drag(find.text('Start scan'), const Offset(0, 400));
    await idle();
    expect(platform.scanStarts, before + 1);
    await tapLabel('Stop scan');
  }
}
