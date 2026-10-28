import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_darwin/flutter_blue_max_darwin.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('pending Darwin connect cancellation completes both public futures',
      () async {
    final plugin = FlutterBlueMaxDarwin();
    FlutterBlueMaxPlatform.instance = plugin;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final connectStarted = Completer<void>();
    const remoteId = '12345678-1234-1234-1234-123456789abc';
    var disconnectCalls = 0;
    messenger.setMockMethodCallHandler(plugin.methodChannel, (call) async {
      switch (call.method) {
        case 'flutterRestart':
          return 0;
        case 'getAdapterState':
          return {'adapter_state': BmAdapterStateEnum.on.index};
        case 'connect':
          connectStarted.complete();
          return true;
        case 'disconnect':
          disconnectCalls++;
          // Native terminal callbacks carry this cancellation payload. The
          // native suite separately exercises the real connect/disconnect path.
          binding.channelBuffers.push(
            plugin.methodChannel.name,
            const StandardMethodCodec().encodeMethodCall(const MethodCall(
              'OnConnectionStateChanged',
              {
                'remote_id': remoteId,
                'connection_state': 0,
                'disconnect_reason_code': 23789258,
                'disconnect_reason_string': 'connection canceled',
              },
            )),
            (_) {},
          );
          return true;
        default:
          fail('Unexpected platform method ${call.method}');
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(plugin.methodChannel, null);
    });

    final device = BluetoothDevice.fromId(remoteId);
    final connecting =
        device.connect(mtu: null, timeout: const Duration(seconds: 2));
    final cancelled = expectLater(
      connecting,
      throwsA(isA<FlutterBlueMaxException>().having(
        (error) => error.code,
        'code',
        FbpErrorCode.connectionCanceled.index,
      )),
    );
    await connectStarted.future;
    await device.disconnect(queue: false, timeout: 2, androidDelay: 0);
    await cancelled;
    expect(disconnectCalls, 1);
    expect(device.isDisconnected, isTrue);
  });
}
