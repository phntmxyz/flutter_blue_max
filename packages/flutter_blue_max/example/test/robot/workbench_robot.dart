import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/app/workbench_app.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/l2cap/l2cap_channel_card.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import '../fakes/fake_bluetooth_platform.dart';

class WorkbenchRobot {
  WorkbenchRobot(this.tester, this.platform);
  final WidgetTester tester;
  final FakeBluetoothPlatform platform;
  final controller = WorkbenchController();

  Future<void> launch({required Size size}) async {
    logEvent('Launch the real workbench at $size');
    addTearDown(dispose);
    FlutterBlueMaxPlatform.instance = platform;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(WorkbenchApp(controller: controller));
    await idle();
    platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on));
    await idle();
  }

  Future<void> dispose() async {
    logEvent('Close the workbench');
    platform.holdConnections = false;
    platform.includeGattExtras = false;
    platform.emitNotifyDescriptorEvents = true;
    platform.systemPeers.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await idle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  }

  Future<void> idle() async {
    await tester.runAsync(() async {});
    await tester.pump();
    for (var frame = 0; frame < 30 && tester.binding.hasScheduledFrame; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {});
      if (controller.scanning) {
        break;
      }
    }
    await tester.runAsync(() async {});
    await tester.pump();
  }

  void logEvent(String description) {
    debugPrint(description);
    timeline.addEvent(eventType: 'robot', details: description);
  }

  Future<void> scanForPeripheral({bool includeSecondPeer = false}) async {
    await tapLabel('Start scan');
    logEvent('Receive a peripheral advertisement from native I/O');
    platform.advertise();
    if (includeSecondPeer) {
      platform.advertise(id: 'AA:BB:CC:DD:EE:02', name: 'Other peripheral');
    }
    await idle();
    await tapLabel('Stop scan');
    spotText('Test peripheral').existsOnce();
  }

  Future<void> inspectPeripheral() async {
    await selectPeripheral();
    await connectSelected();
    expect(controller.connected, isTrue);
    await tapLabel('Discover services');
    spotText('180F').existsOnce();
  }

  Future<void> selectPeripheral({String name = 'Test peripheral'}) async {
    logEvent('Select "$name" in the device list');
    final tile = spot<ListTile>().withChild(spotText(name, exact: true))..existsOnce();
    await tester.ensureVisible(find.widgetWithText(ListTile, name));
    await idle();
    await act.tap(tile);
    await idle();
  }

  Future<void> connectSelected() => tapLabel('Connect');

  void expectLocalDeviceName() {
    logEvent('Verify the local device name in discovery');
    spotText('This device: Test workstation', exact: true).existsOnce();
  }

  void expectConnectionRequired() {
    logEvent('Verify that the device must be connected before entering a remote PSM');
    spotText('Connect this device above to open an L2CAP channel.', exact: true).existsOnce();
    spot<TextFormField>().doesNotExist();
    spotText('Open channel', exact: true).doesNotExist();
  }

  void expectEmptyPsm() {
    logEvent('Verify that a different peer does not inherit the previous PSM');
    final field = spot<TextFormField>()..existsOnce();
    expect(field.snapshotWidget().controller!.text, isEmpty);
  }

  Future<void> openL2cap() => tapLabel('L2CAP');
  Future<void> openLocalServer() => tapLabel('Local server');
  Future<void> readAndWriteCharacteristic() async {
    await tapLabel('180F');
    await tapLabel('2A19');
    await tapLabel('Read');
    spotText('64', exact: true).existsOnce();
    await tapLabel('Write');
    logEvent('Enter a malformed payload and verify that it is not transmitted');
    final field = spot<TextFormField>()..existsOnce();
    await tester.ensureVisible(find.byType(TextFormField));
    await act.enterText(field, 'F');
    await idle();
    final count = platform.characteristicWrites.length;
    await tapLabel('Write characteristic');
    expect(platform.characteristicWrites, hasLength(count));
    logEvent('Send valid hex using the characteristic’s write-without-response capability');
    field.existsOnce();
    await act.enterText(field, '01 A2 FF');
    await idle();
    await tapLabel('Write characteristic');
    expect(platform.characteristicWrites.last.value, [1, 162, 255]);
    expect(platform.characteristicWrites.last.writeType, BmWriteType.withoutResponse);
  }

  Future<void> startServer() => tapLabel('Start server');
  Future<void> stopServer() => tapLabel('Stop server');
  Future<void> openActivity() => tapLabel('Activity');

  Future<void> rejectUnsupportedServer() async {
    logEvent('Report an unsupported server from the platform boundary');
    platform.l2capFailure = UnimplementedError();
    addTearDown(() => platform.l2capFailure = null);
    await startServer();
    spotText('This operation is not supported on this device.', exact: true).existsOnce();
    expect(controller.serverPsm, isNull);
    expect(controller.busy('server'), isFalse);
  }

  Future<void> dismissUnsupportedError() async {
    logEvent('Dismiss the unsupported-operation message');
    final close = spot<IconButton>().withTooltip('Dismiss error')..existsOnce();
    await act.tap(close);
    await idle();
    spotText('This operation is not supported on this device.', exact: true).doesNotExist();
  }

  Future<void> filterWithKeyboard() async {
    logEvent('Filter devices while the phone keyboard reduces the viewport');
    final field = spot<TextField>()..existsOnce();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await act.enterText(field, 'missing peripheral');
    await idle();
    expect(controller.visibleDevices, isEmpty);
    tester.view.resetViewInsets();
    await idle();
    spotText('No matching devices', exact: true).existsOnce();
    field.existsOnce();
    await act.enterText(field, 'Test peripheral');
    await idle();
    spot<ListTile>().withChild(spotText('Test peripheral', exact: true)).existsOnce();
    tester.view.resetViewInsets();
    await idle();
  }

  Future<void> rotateToLandscape() async {
    logEvent('Rotate the phone to landscape');
    tester.view.physicalSize = const Size(844, 390);
    await idle();
  }

  Future<void> returnToDeviceList() async {
    logEvent('Use the system back action from the device inspector');
    spotText('180F', exact: true).existsOnce();
    await tester.binding.handlePopRoute();
    await idle();
    spot<ListTile>().withChild(spotText('Test peripheral', exact: true)).existsOnce();
    expect(controller.connected, isTrue);
  }

  Future<void> reopenConnectedPeripheral() async {
    await selectPeripheral();
    logEvent('Verify that reopening a connected peer refreshes its signal strength');
    spotText('-47 dBm', exact: true).existsOnce();
    expect(controller.connected, isTrue);
    expect(controller.error, isNull);
  }

  void expectListening() {
    logEvent('Verify that server state survives navigation');
    expect(controller.serverPsm, 129);
    spotText('Stop server').existsOnce();
    spotText('Waiting for a peer — no channel connected yet.', exact: true).existsOnce();
  }

  Future<void> acceptIncomingChannel() async {
    logEvent('Receive an incoming channel and distinguish it from a waiting server');
    platform.accepted.add(L2CapChannelConnected(remoteId: DeviceIdentifier('AA:BB:CC:DD:EE:03'), psm: 129));
    await idle();
    expect(controller.channels.single.incoming, isTrue);
    spotText('Waiting for a peer — no channel connected yet.', exact: true).doesNotExist();
    spotText('1 incoming channel connected.', exact: true).existsOnce();
  }

  void expectStopped() {
    expect(controller.serverPsm, isNull);
    spotText('Start server').existsOnce();
  }

  Future<void> rejectInvalidRemotePsm() async {
    logEvent('Enter an invalid remote PSM');
    final field = spot<TextFormField>();
    field.existsOnce();
    await tester.ensureVisible(find.byType(TextFormField));
    await idle();
    await act.enterText(field, '0');
    await idle();
    await tapLabel('Open channel');
    spotText('Enter a PSM from 1 to 65535, in decimal or 0x hexadecimal.').existsOnce();
    expect(controller.channels, isEmpty);
  }

  Future<void> openRemoteChannel() async {
    logEvent('Open an L2CAP channel to the connected device');
    final field = spot<TextFormField>()..existsOnce();
    await tester.ensureVisible(find.byType(TextFormField));
    await idle();
    await act.enterText(field, '131');
    await idle();
    await tapLabel('Open channel');
    final session = controller.channels.where((s) => s.channel.deviceId == controller.selected!.remoteId).single;
    expect(session.incoming, isFalse);
    await expectOnlySelectedChannel();
  }

  Future<void> expectOnlySelectedChannel() async {
    logEvent('Verify that only the inspected peer’s channel is displayed');
    final card = spot<L2capChannelCard>()..existsOnce();
    await tester.ensureVisible(find.byType(L2capChannelCard));
    await idle();
    expect(card.snapshotWidget().session.channel.deviceId, controller.selected!.remoteId);
    spotText('Outgoing · PSM 131', exact: true).existsOnce();
  }

  void expectNoOutgoingChannels() {
    logEvent('Verify that the local server only shows incoming channels');
    spotText('Outgoing · PSM 131', exact: true).doesNotExist();
    spotText('Remote PSM', exact: true).doesNotExist();
  }

  Future<void> tapLabel(String label) async {
    logEvent('Tap "$label"');
    final target = spotText(label, exact: true)..existsOnce();
    await tester.ensureVisible(find.text(label));
    await idle();
    await act.tap(target);
    await idle();
  }
}
