import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_max_darwin/flutter_blue_max_darwin.dart';
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

  test('options are sent before the restart handshake', () async {
    final callOrder = <String>[];
    final plugin = createPlugin((call) async {
      callOrder.add(call.method);
      switch (call.method) {
        case 'setOptions':
          return true;
        case 'flutterRestart':
          return 0;
        case 'isSupported':
          return true;
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    expect(
      await plugin.setOptions(
        BmSetOptionsRequest(showPowerAlert: false, restoreState: true),
      ),
      isTrue,
    );
    expect(await plugin.isSupported(BmIsSupportedRequest()), isTrue);
    expect(callOrder, ['setOptions', 'flutterRestart', 'isSupported']);
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
  for (final missingMethod in ['flutterRestart', 'connectedCount']) {
    test('rejects missing $missingMethod count and retries', () async {
      var missingResponse = true;
      var restartCalls = 0;
      var supportedCalls = 0;
      final plugin = createPlugin((call) async {
        switch (call.method) {
          case 'flutterRestart':
            restartCalls++;
            if (missingResponse && missingMethod == 'flutterRestart') {
              return null;
            }
            return missingResponse ? 1 : 0;
          case 'connectedCount':
            return null;
          case 'isSupported':
            supportedCalls++;
            return true;
          default:
            fail('Unexpected method ${call.method}');
        }
      });

      await expectLater(
        plugin.isSupported(BmIsSupportedRequest()),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'invalidRestartCount',
        )),
      );
      expect(supportedCalls, 0);
      missingResponse = false;
      expect(await plugin.isSupported(BmIsSupportedRequest()), isTrue);
      expect(restartCalls, 2);
      expect(supportedCalls, 1);
    });
  }
  test('timeout releases concurrent callers and allows a retry', () async {
    var draining = true;
    var restartCalls = 0;
    var pollCalls = 0;
    var supportedCalls = 0;
    final plugin = createPlugin((call) async {
      switch (call.method) {
        case 'flutterRestart':
          restartCalls++;
          return draining ? 1 : 0;
        case 'connectedCount':
          pollCalls++;
          return 1;
        case 'isSupported':
          supportedCalls++;
          return true;
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    // Await the shared handshake itself; do not race it with a shorter timer.
    final outcomes = await Future.wait([
      for (var i = 0; i < 2; i++)
        plugin.isSupported(BmIsSupportedRequest()).then<Object>(
              (value) => value,
              onError: (Object error, StackTrace stack) => error,
            ),
    ]);
    expect(outcomes, everyElement(isA<TimeoutException>()));
    expect(identical(outcomes[0], outcomes[1]), isTrue);
    expect((outcomes.first as TimeoutException).duration,
        const Duration(seconds: 10));
    expect(restartCalls, 1);
    expect(pollCalls, greaterThan(0));
    expect(supportedCalls, 0);

    draining = false;
    expect(await plugin.isSupported(BmIsSupportedRequest()), isTrue);
    expect(restartCalls, 2);
    expect(supportedCalls, 1);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

FlutterBlueMaxDarwin createPlugin(
  Future<Object?> Function(MethodCall call) nativeHandler,
) {
  final plugin = FlutterBlueMaxDarwin();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(plugin.methodChannel, nativeHandler);
  addTearDown(() {
    messenger.setMockMethodCallHandler(plugin.methodChannel, null);
  });
  return plugin;
}
