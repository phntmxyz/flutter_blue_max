import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_bluetooth_platform.dart';
import '../robot/workbench_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeBluetoothPlatform();
  // Plugin subscriptions outlive each widget test's fake clock, as they do app screens.
  setUpAll(() async {
    FlutterBlueMaxPlatform.instance = platform;
    await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
  });

  testWidgets('desktop: discover GATT, validate PSM and preserve server across navigation', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    robot.expectLocalDeviceName();
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.readAndWriteCharacteristic();
    await robot.openL2cap();
    await robot.rejectInvalidRemotePsm();
    await robot.openRemoteChannel();
    await robot.openLocalServer();
    robot.expectNoOutgoingChannels();
    await robot.startServer();
    await robot.openActivity();
    await robot.openLocalServer();
    robot.expectListening();
    await robot.stopServer();
    robot.expectStopped();
  });

  testWidgets('phone: local server is available without selecting a peripheral', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    robot.expectLocalDeviceName();
    await robot.openLocalServer();
    await robot.startServer();
    await robot.openActivity();
    await robot.openLocalServer();
    robot.expectListening();
    await robot.acceptIncomingChannel();
    await robot.stopServer();
    robot.expectStopped();
  });

  testWidgets('compact phone: keyboard and landscape keep workspaces scrollable', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(360, 640));
    await robot.scanForPeripheral();
    await robot.filterWithKeyboard();
    await robot.rotateToLandscape();
    await robot.openLocalServer();
    await robot.startServer();
    await robot.openActivity();
    await robot.openLocalServer();
    await robot.stopServer();
  });

  testWidgets('phone: system back returns to the list without dropping the connection', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.returnToDeviceList();
    await robot.reopenConnectedPeripheral();
  });

  testWidgets('phone: outgoing L2CAP requires a connection but no GATT discovery', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.selectPeripheral();
    await robot.openL2cap();
    robot.expectConnectionRequired();
    await robot.connectSelected();
    await robot.openRemoteChannel();
  });

  testWidgets('desktop: channels and remote PSM input belong to the inspected device', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.scanForPeripheral(includeSecondPeer: true);
    await robot.selectPeripheral();
    await robot.connectSelected();
    await robot.openL2cap();
    await robot.openRemoteChannel();
    await robot.selectPeripheral(name: 'Other peripheral');
    await robot.connectSelected();
    await robot.openL2cap();
    robot.expectEmptyPsm();
    await robot.openRemoteChannel();
    await robot.selectPeripheral();
    await robot.openL2cap();
    await robot.expectOnlySelectedChannel();
  });

  testWidgets('unsupported server reports a dismissible message and GATT remains usable', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.openLocalServer();
    await robot.rejectUnsupportedServer();
    await robot.dismissUnsupportedError();
    await robot.tapLabel('Devices');
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.readAndWriteCharacteristic();
  });
}
