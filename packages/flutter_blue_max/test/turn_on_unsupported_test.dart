import "dart:async";

import "package:flutter_blue_max/flutter_blue_max.dart";
import "package:flutter_blue_max_darwin/flutter_blue_max_darwin.dart";
import "package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("turnOn passes on the unsupported error of the Darwin implementation", () async {
    final plugin = FlutterBlueMaxDarwin();
    FlutterBlueMaxPlatform.instance = plugin;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(plugin.methodChannel, (call) async {
      switch (call.method) {
        case "flutterRestart":
          return 0;
        case "turnOn":
          fail("turnOn must not reach the native plugin");
        default:
          return true;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(plugin.methodChannel, null);
    });

    final unhandled = <Object>[];
    await runZonedGuarded(
      () async {
        await expectLater(FlutterBlueMax.turnOn(timeout: 1), throwsUnsupportedError);
        // let the abandoned turn on response settle
        await Future<void>.delayed(Duration.zero);
      },
      (error, stackTrace) => unhandled.add(error),
    );
    expect(unhandled, isEmpty);
  });
}
