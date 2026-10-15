import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_bluetooth_platform.dart';
import '../robot/restored_features_robot.dart';
import '../robot/workbench_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeBluetoothPlatform();
  // Plugin subscriptions outlive each widget test's fake clock, as they do app screens.
  setUpAll(() async {
    FlutterBlueMaxPlatform.instance = platform;
    await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
  });

  testWidgets('system-connected peers remain discoverable without advertisements', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.connectSystemPeer();
  });

  testWidgets('phone: cancel a pending connection', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.selectPeripheral();
    await robot.cancelPendingConnection();
  });

  testWidgets('L2CAP exposes large writes, burst traffic, buffer reads and receive history', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.scanForPeripheral();
    await robot.selectPeripheral();
    await robot.connectSelected();
    await robot.openL2cap();
    await robot.openRemoteChannel();
    await robot.exerciseL2capTraffic();
  });

  testWidgets('GATT subscriptions and descriptor operations remain reachable', (tester) async {
    platform.includeGattExtras = true;
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.exerciseNotificationsAndDescriptors();
  });

  testWidgets('broadcast advertisements retain appearance and cannot be connected', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.checkBroadcastAndAppearance();
  });

  testWidgets('Android exposes the adapter turn-on action', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.enableBluetooth();
  });

  testWidgets('phone: pull-to-refresh starts a new scan', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.pullToRefreshDevices();
  });
}
