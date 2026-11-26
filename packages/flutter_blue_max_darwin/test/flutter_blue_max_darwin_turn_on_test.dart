import "package:flutter/services.dart";
import "package:flutter_blue_max_darwin/flutter_blue_max_darwin.dart";
import "package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("turnOn is unsupported and never reaches the native plugin", () async {
    final plugin = FlutterBlueMaxDarwin();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final nativeCalls = <String>[];
    messenger.setMockMethodCallHandler(plugin.methodChannel, (MethodCall call) async {
      nativeCalls.add(call.method);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(plugin.methodChannel, null);
    });

    await expectLater(plugin.turnOn(BmTurnOnRequest()), throwsUnsupportedError);
    expect(nativeCalls, isEmpty);
  });
}
