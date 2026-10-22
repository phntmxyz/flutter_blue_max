import 'package:flutter/services.dart';
import 'package:flutter_blue_max_android/flutter_blue_max_android.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent first calls share one hot-restart handshake', () async {
    var restartCalls = 0;
    var supportedCalls = 0;
    final plugin = createPlugin((call) async {
      switch (call.method) {
        case 'flutterRestart':
          restartCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 0;
        case 'isSupported':
          supportedCalls++;
          return true;
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    final results = await Future.wait([
      plugin.isSupported(BmIsSupportedRequest()),
      plugin.isSupported(BmIsSupportedRequest()),
    ]);

    expect(results, [true, true]);
    expect(restartCalls, 1);
    expect(supportedCalls, 2);
  });

  test('a failed hot-restart handshake is retried', () async {
    var restartCalls = 0;
    final plugin = createPlugin((call) async {
      switch (call.method) {
        case 'flutterRestart':
          restartCalls++;
          if (restartCalls == 1) {
            throw PlatformException(code: 'restartFailed');
          }
          return 0;
        case 'isSupported':
          return true;
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    await expectLater(
      plugin.isSupported(BmIsSupportedRequest()),
      throwsA(isA<PlatformException>()),
    );
    expect(await plugin.isSupported(BmIsSupportedRequest()), isTrue);
    expect(restartCalls, 2);
  });

  test('platform work waits until native restart cleanup completes', () async {
    var connectedCountCalls = 0;
    final callOrder = <String>[];
    final plugin = createPlugin((call) async {
      callOrder.add(call.method);
      switch (call.method) {
        case 'flutterRestart':
          return 2;
        case 'connectedCount':
          connectedCountCalls++;
          return connectedCountCalls == 1 ? 1 : 0;
        case 'isSupported':
          return true;
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    expect(await plugin.isSupported(BmIsSupportedRequest()), isTrue);
    expect(callOrder, [
      'flutterRestart',
      'connectedCount',
      'connectedCount',
      'isSupported',
    ]);
  });
}

FlutterBlueMaxAndroid createPlugin(
  Future<Object?> Function(MethodCall call) nativeHandler,
) {
  final plugin = FlutterBlueMaxAndroid();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(plugin.methodChannel, nativeHandler);
  addTearDown(() {
    messenger.setMockMethodCallHandler(plugin.methodChannel, null);
  });
  return plugin;
}
