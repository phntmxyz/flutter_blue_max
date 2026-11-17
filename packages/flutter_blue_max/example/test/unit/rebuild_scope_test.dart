import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/activity/activity_panel.dart';
import 'package:flutter_blue_max_example/app/workbench_app.dart';
import 'package:flutter_blue_max_example/devices/devices_panel.dart';
import 'package:flutter_blue_max_example/l2cap/l2cap_server_panel.dart';
import 'package:flutter_blue_max_example/library/library_panel.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import '../fakes/fake_bluetooth_platform.dart';
import '../robot/workbench_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeBluetoothPlatform();
  setUpAll(() async {
    FlutterBlueMaxPlatform.instance = platform;
    await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
  });

  testWidgets('the adapter banner updates while remaining mounted', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off));
    await robot.idle();
    spot<AdapterBanner>().spotText('Bluetooth is off.').existsOnce();
    platform.adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.unauthorized));
    await robot.idle();
    spot<AdapterBanner>().spotText('Bluetooth permission is denied.').existsOnce();
    spot<AdapterBanner>().spotText('Bluetooth is off.').doesNotExist();
  });

  const panels = [DevicesPanel, L2capServerPanel, LibraryPanel, ActivityPanel];

  testWidgets('logs and discovery rebuild only the panels that use them', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));

    final builds = <Type, int>{};
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final type = element.widget.runtimeType;
      if (panels.contains(type)) builds[type] = (builds[type] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    // 1) Ten app log lines, one frame each, with the Devices tab selected.
    for (var i = 0; i < 10; i++) {
      robot.controller.log('probe line $i');
      await tester.pump();
    }

    for (final type in panels) {
      expect(builds[type] ?? 0, type == ActivityPanel ? 10 : 0, reason: '$type log rebuild count');
    }
    expect(find.byType(ActivityPanel, skipOffstage: false), findsOneWidget);
    expect(find.byType(ActivityPanel), findsNothing, reason: 'Activity is not the visible tab');

    // 2) A single scan-result batch from the fake platform.
    builds.clear();
    await robot.tapLabel('Start scan');
    builds.clear();
    platform.advertise();
    await tester.pump();

    for (final type in panels) {
      expect(builds[type] ?? 0, type == DevicesPanel ? greaterThan(0) : 0, reason: '$type scan rebuild count');
    }
    await robot.tapLabel('Stop scan');
    builds.clear();
    await robot.controller.startServer(secure: true);
    await tester.pump();
    expect(builds[L2capServerPanel], greaterThan(0));
    expect(builds[DevicesPanel] ?? 0, 0);
    expect(builds[LibraryPanel] ?? 0, 0);
  });
}
