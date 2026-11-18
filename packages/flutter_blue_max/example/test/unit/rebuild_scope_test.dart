import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/activity/activity_panel.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_card.dart';
import 'package:flutter_blue_max_example/app/workbench_app.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/devices/devices_panel.dart';
import 'package:flutter_blue_max_example/l2cap/l2cap_server_panel.dart';
import 'package:flutter_blue_max_example/library/library_panel.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('rebinding a workbench retires only the controllers it owns', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final injected = WorkbenchController();
    addTearDown(injected.dispose);

    WorkbenchController boundController() => tester.element(spot<DevicesPanel>().finder).read<WorkbenchController>();

    await tester.pumpWidget(const WorkbenchApp());
    await tester.pumpAndSettle();
    final first = boundController();

    await tester.pumpWidget(WorkbenchApp(controller: injected));
    await tester.pumpAndSettle();
    expect(boundController(), same(injected));
    expect(() => ChangeNotifier.debugAssertNotDisposed(first), throwsFlutterError);

    await tester.pumpWidget(const WorkbenchApp());
    await tester.pumpAndSettle();
    final last = boundController();
    expect(last, isNot(same(first)));
    expect(last, isNot(same(injected)));
    expect(ChangeNotifier.debugAssertNotDisposed(injected), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(() => ChangeNotifier.debugAssertNotDisposed(last), throwsFlutterError);
    expect(ChangeNotifier.debugAssertNotDisposed(injected), isTrue);
  });

  testWidgets('navigation stays reachable in a short wide workbench', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 230));
    expect(tester.takeException(), isNull);
    await robot.tapLabel('Activity');
    spot<ActivityPanel>().existsOnce();
    expect(tester.takeException(), isNull);
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

  const panels = [
    DevicesPanel,
    DeviceDiscoveryList,
    DeviceDetails,
    AdvertisementCard,
    GattExplorer,
    L2capServerPanel,
    LibraryPanel,
    ActivityLog,
  ];

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
      expect(builds[type] ?? 0, type == ActivityLog ? 10 : 0, reason: '$type log rebuild count');
    }
    spotAllWidgets().spot<ActivityPanel>().existsOnce();
    spot<ActivityPanel>().doesNotExist();

    // 2) A single scan-result batch from the fake platform.
    builds.clear();
    await robot.tapLabel('Start scan');
    builds.clear();
    platform.advertise();
    await tester.pump();

    for (final type in panels) {
      expect(builds[type] ?? 0, type == DeviceDiscoveryList ? greaterThan(0) : 0, reason: '$type scan rebuild count');
    }
    // A new sample for the same peer should update its visible name and RSSI.
    spotText('Test peripheral', exact: true).existsOnce();
    platform.advertise(name: 'Updated peripheral', rssi: -63);
    await tester.pump();
    spotText('Updated peripheral', exact: true).existsOnce();

    await robot.tapLabel('Stop scan');
    await robot.selectPeripheral(name: 'Updated peripheral');
    await robot.tapLabel('Advertisement');
    await robot.tapLabel('Track advertisements');
    builds.clear();
    platform.advertise(name: 'Updated peripheral', rssi: -64);
    await robot.idle();
    expect(builds[AdvertisementCard], greaterThan(0));
    expect(builds[DeviceDiscoveryList], greaterThan(0));
    expect(builds[DevicesPanel] ?? 0, 0);
    expect(builds[DeviceDetails] ?? 0, 0);
    expect(builds[GattExplorer] ?? 0, 0);
    spotText('-64 dBm · Connectable · Tracking 1', exact: true).existsOnce();

    await robot.tapLabel('Stop tracking');
    final inspector = spot<DeviceDetails>().spot<Scrollable>().withChild(spot<SliverPadding>())..existsOnce();
    await tester.scrollUntilVisible(spotText('Connect', exact: true).finder, -200, scrollable: inspector.finder);
    await robot.tapLabel('Advertisement');
    await robot.connectSelected();
    await robot.tapLabel('Discover services');
    spotText('Battery', exact: true).existsOnce();
    platform.overrideReadRssi = (request) async {
      platform.rssiValues.add(
        BmReadRssiResult(remoteId: request.remoteId, rssi: -52, success: true, errorCode: 0, errorString: ''),
      );
      return true;
    };
    builds.clear();
    await robot.tapLabel('Read RSSI');
    spot<DeviceDetails>().spotText('-52 dBm', exact: true).existsOnce();
    expect(builds[DeviceDetails], greaterThan(0));
    expect(builds[GattExplorer] ?? 0, 0);

    builds.clear();
    await robot.controller.startServer(secure: true);
    await tester.pump();
    expect(builds[L2capServerPanel], greaterThan(0));
    expect(builds[DevicesPanel] ?? 0, 0);
    expect(builds[LibraryPanel] ?? 0, 0);
  });
}
