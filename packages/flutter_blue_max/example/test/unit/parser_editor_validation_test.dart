import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_blue_max/flutter_blue_max.dart";
import "package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";

import "../fakes/fake_bluetooth_platform.dart";
import "../robot/advertisement_robot.dart";
import "../robot/workbench_robot.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeBluetoothPlatform();
  setUpAll(() async {
    FlutterBlueMaxPlatform.instance = platform;
    await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
  });

  testWidgets("web: the Library editor rejects invalid parsers until corrected", (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1400, 2000));
    await robot.validatePreviewBeforeSaving(withSample: false);
  }, skip: !kIsWeb);
}
