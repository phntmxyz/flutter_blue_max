# Mocking guide

How to test code that uses `FlutterBlueMax`.

## Overview

`FlutterBlueMax` is a set of static functions on top of a platform interface, `FlutterBlueMaxPlatform`.
Static functions cannot be replaced in a test, so a test replaces what sits below or above them.

| Approach | The test replaces | Use it when |
|---|---|---|
| [Fake the platform](#fake-the-platform) | The native plugin below `FlutterBlueMax` | Your code calls the static functions, for example to scan or to read the adapter state |
| [Fake the devices](#fake-the-devices) | `BluetoothDevice` and `BluetoothCharacteristic` | Your code gets a device handed in and the test controls what it answers |
| [Wrap the static calls](#wrap-the-static-calls) | A class of your own above `FlutterBlueMax` | A test has to hand its fake devices to your code through the scan results |

The approaches combine: a test can scan through a fake platform and hand a fake device to the code that connects.

## Fake the platform

A fake platform stands in for the native plugin.
The real `FlutterBlueMax` code keeps running on top of it, so the test covers how your code and `flutter_blue_max` work together.

Add the platform interface to your `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_blue_max_platform_interface: ^6.0.0
```

Extend `FlutterBlueMaxPlatform` and override what your code reaches.
This fake answers a scan:

```dart
import 'dart:async';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';

final class FlutterBlueMaxFake extends FlutterBlueMaxPlatform {
  final scanResponses = StreamController<BmScanResponse>.broadcast(sync: true);
  BmScanSettings? lastScan;

  @override
  Stream<BmScanResponse> get onScanResponse => scanResponses.stream;

  @override
  Future<BmBluetoothAdapterState> getAdapterState(BmBluetoothAdapterStateRequest request) async {
    return BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);
  }

  @override
  Future<bool> startScan(BmScanSettings request) async {
    lastScan = request;
    return true;
  }

  @override
  Future<bool> stopScan(BmStopScanRequest request) async => true;

  /// Reports the advertisement of a device, as the native plugin does during a scan.
  void advertise(String remoteId, {List<Guid> serviceUuids = const []}) {
    scanResponses.add(
      BmScanResponse(
        advertisements: [
          BmScanAdvertisement(
            remoteId: DeviceIdentifier(remoteId),
            platformName: null,
            advName: null,
            connectable: true,
            txPowerLevel: null,
            appearance: null,
            manufacturerData: const {},
            serviceData: const {},
            serviceUuids: serviceUuids,
            rssi: -50,
          ),
        ],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
  }
}
```

Install it before the code under test runs:

```dart
test('lists the devices that advertise the heart rate service', () async {
  final fake = FlutterBlueMaxFake();
  FlutterBlueMaxPlatform.instance = fake;
  addTearDown(FlutterBlueMax.stopScan);

  await FlutterBlueMax.startScan(withServices: [Guid('180D')]);
  fake.advertise('AA:BB:CC:DD:EE:FF', serviceUuids: [Guid('180D')]);
  final results = await FlutterBlueMax.onScanResults.firstWhere((results) => results.isNotEmpty);

  expect(fake.lastScan!.withServices, [Guid('180D')]);
  expect(results.single.device.remoteId.str, 'AA:BB:CC:DD:EE:FF');
});
```

A method that the fake does not override answers like a platform without Bluetooth: with `false`, an unknown adapter state, an empty stream or an `UnimplementedError`.

### State that outlives a test

`FlutterBlueMax` keeps its state in static fields, and all tests of a file share them.

- A scan that a test leaves running is still running in the next test.
  Stop it in a tear down, as the example above does.
- `FlutterBlueMax` subscribes once to the streams it tracks permanently: the adapter state, the connection state, the MTU, the bond state, the device name and the discovered services.
  It does so on its first call, on the platform that is installed at that moment.
  A fake that a later test installs does not get these subscriptions, so a connection state it reports does not reach `device.isConnected`.
- The scan response is subscribed with every `startScan`, so scanning works with a new fake per test.

A test file that needs the tracked streams installs one fake for all its tests and resets it between them:

```dart
final fake = FlutterBlueMaxFake();

void main() {
  setUp(() {
    FlutterBlueMaxPlatform.instance = fake;
  });
}
```

Each test file runs in an isolate of its own, so the state does not travel between files.

## Fake the devices

`BluetoothDevice`, `BluetoothService` and `BluetoothCharacteristic` are regular classes.
Code that takes a device as an argument can be tested with a subclass that overrides what the code calls:

```dart
class FakeDevice extends BluetoothDevice {
  FakeDevice() : super.fromId('AA:BB:CC:DD:EE:FF');

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    _connected = true;
  }

  @override
  Future<void> disconnect({int timeout = 35, bool queue = true, int androidDelay = 2000}) async {
    _connected = false;
  }
}
```

A member that the subclass does not override still calls the platform.
Override everything the code under test reaches, or install a fake platform as well.

## Wrap the static calls

The scan results of `FlutterBlueMax` always carry real `BluetoothDevice` objects.
When a test has to hand a fake device to your code through the scan, the scan itself has to be replaceable.
Wrap the static calls that your app uses in a class of your own and pass an instance of it to your code:

```dart
class BluetoothScanner {
  Stream<List<ScanResult>> get onScanResults => FlutterBlueMax.onScanResults;

  Future<void> startScan({required List<Guid> withServices}) {
    return FlutterBlueMax.startScan(withServices: withServices);
  }

  Future<void> stopScan() => FlutterBlueMax.stopScan();
}
```

A test passes a subclass that emits its own scan results:

```dart
class FakeBluetoothScanner extends BluetoothScanner {
  final results = StreamController<List<ScanResult>>.broadcast(sync: true);

  @override
  Stream<List<ScanResult>> get onScanResults => results.stream;

  @override
  Future<void> startScan({required List<Guid> withServices}) async {}

  @override
  Future<void> stopScan() async {}
}
```

Wrap only the calls your app makes.
A wrapper that mirrors all of `FlutterBlueMax` has to follow every change of its signatures.
The wrapper replaces `flutter_blue_max` in the test, so the test no longer covers how your code and the real scan work together.
