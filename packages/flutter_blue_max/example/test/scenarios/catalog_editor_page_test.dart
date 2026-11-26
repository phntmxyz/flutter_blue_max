import "package:flutter/material.dart";
import "package:flutter_blue_max/flutter_blue_max.dart";
import "package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";

import "../fakes/fake_bluetooth_platform.dart";
import "../robot/gatt_catalog_robot.dart";
import "../robot/workbench_robot.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeBluetoothPlatform();
  setUpAll(() async {
    FlutterBlueMaxPlatform.instance = platform;
    await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
  });

  testWidgets("catalog editor: removing a field keeps validation with its own characteristic", (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 1000));
    await robot.removeInvalidCharacteristicWithoutMovingErrors();
  });

  testWidgets("the catalog editor rejects invalid entries and edits in place", (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.validateCatalogEditor();
  });

  testWidgets("catalog editor keeps its draft after a background tap dismisses the keyboard", (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.dismissCatalogKeyboard();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
