import "package:flutter/services.dart";
import "package:flutter_blue_max/flutter_blue_max.dart";
import "package:flutter_blue_max_darwin/flutter_blue_max_darwin.dart";
import "package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test("a failed Darwin read without a value ends in its error and is no event", () async {
    final plugin = FlutterBlueMaxDarwin();
    FlutterBlueMaxPlatform.instance = plugin;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const remoteId = "12345678-1234-1234-1234-123456789abc";
    const serviceUuid = "180a";
    const characteristicUuid = "2a29";
    const insufficientAuthentication = 5;

    void sendFromNative(String method, Map<String, Object?> arguments) {
      binding.channelBuffers.push(
        plugin.methodChannel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
    }

    messenger.setMockMethodCallHandler(plugin.methodChannel, (call) async {
      switch (call.method) {
        case "flutterRestart":
          return 0;
        case "getAdapterState":
          return {"adapter_state": BmAdapterStateEnum.on.index};
        case "connect":
          sendFromNative("OnConnectionStateChanged", {
            "remote_id": remoteId,
            "connection_state": BmConnectionStateEnum.connected.index,
            "disconnect_reason_code": null,
            "disconnect_reason_string": null,
          });
          return true;
        case "readCharacteristic":
          // iOS & macOS send no value when the peer answers a read with an ATT error
          sendFromNative("OnCharacteristicReceived", {
            "remote_id": remoteId,
            "service_uuid": serviceUuid,
            "characteristic_uuid": characteristicUuid,
            "primary_service_uuid": null,
            "instance_id": null,
            "value": null,
            "success": 0,
            "error_string": "Authentication is insufficient.",
            "error_code": insufficientAuthentication,
          });
          return true;
        default:
          return true;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(plugin.methodChannel, null);
    });

    final events = <OnCharacteristicReceivedEvent>[];
    final subscription = FlutterBlueMax.events.onCharacteristicReceived.listen(events.add);
    addTearDown(subscription.cancel);

    final device = BluetoothDevice.fromId(remoteId);
    await device.connect(mtu: null, timeout: const Duration(seconds: 2));
    final characteristic = BluetoothCharacteristic(
      remoteId: device.remoteId,
      serviceUuid: Guid(serviceUuid),
      characteristicUuid: Guid(characteristicUuid),
    );

    await expectLater(
      characteristic.read(timeout: 2),
      throwsA(isA<FlutterBlueMaxException>()
          .having((error) => error.code, "code", insufficientAuthentication)
          .having((error) => error.description, "description", "Authentication is insufficient.")),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    expect(characteristic.lastValue, isEmpty);
  });
}
