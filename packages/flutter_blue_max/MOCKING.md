# Mocking guide

How to mock `FlutterBlueMax` for testing.

## Overview

Since version [1.10.0](https://pub.dev/packages/flutter_blue_max/changelog#1100), `FlutterBlueMax.instance` has been deprecated in favor of static functions. 

Therefore, to mock FlutterBlueMax you must:

1. Wrap `FlutterBlueMax` in a mockable non-static class
2. Add your mocked functions to the mockable class.
2. Use the mockable class in your code

A full example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).

## Mockable class

Create the following class:

```dart
import '../flutter_blue_max.dart';

/// Wrapper for FlutterBlueMax in order to easily mock it
/// Wraps all static calls for testing purposes
class FlutterBlueMaxMockable {
  Future<void> startScan({
    List<Guid> withServices = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool oneByOne = false,
    bool androidUsesFineLocation = false,
  }) {
    return FlutterBlueMax.startScan(
        withServices: withServices,
        timeout: timeout,
        removeIfGone: removeIfGone,
        oneByOne: oneByOne,
        androidUsesFineLocation: androidUsesFineLocation);
  }

  Stream<BluetoothAdapterState> get adapterState {
    return FlutterBlueMax.adapterState;
  }

  Stream<List<ScanResult>> get scanResults {
    return FlutterBlueMax.scanResults;
  }

  bool get isScanningNow {
    return FlutterBlueMax.isScanningNow;
  }

  Stream<bool> get isScanning {
    return FlutterBlueMax.isScanning;
  }

  Future<void> stopScan() {
    return FlutterBlueMax.stopScan();
  }

  void setLogLevel(LogLevel level, {color = true}) {
    return FlutterBlueMax.setLogLevel(level, color: color);
  }

  LogLevel get logLevel {
    return FlutterBlueMax.logLevel;
  }

  Future<bool> get isSupported {
    return FlutterBlueMax.isSupported;
  }

  Future<String> get adapterName {
    return FlutterBlueMax.adapterName;
  }

  Future<void> turnOn({int timeout = 60}) {
    return FlutterBlueMax.turnOn(timeout: timeout);
  }

  List<BluetoothDevice> get connectedDevices {
    return FlutterBlueMax.connectedDevices;
  }

  Future<List<BluetoothDevice>> get systemDevices {
    return FlutterBlueMax.systemDevices;
  }

  Future<PhySupport> getPhySupport() {
    return FlutterBlueMax.getPhySupport();
  }

  Future<List<BluetoothDevice>> get bondedDevices {
    return FlutterBlueMax.bondedDevices;
  }
}
```

## Mock the wrapper class

Using e.g. [Mockito](https://pub.dev/packages/mockito), create a mock for the `FlutterBlueMaxMockable` class, and build your tests and stubs.

## Create instance

Use the mockable class where needed, e.g. in `main.dart`:

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);
  //instance of FlutterBlueMax that will be passed
  //throughout the app as necessary
  FlutterBlueMaxMockable bluePlusMockable = FlutterBlueMaxMockable();//<--

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My app',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home:  FindDevicesScreen(
        bluePlusMockable: bluePlusMockable,
      );
    );
  }
}
```

## Use mock instead of FlutterBlueMax

Within your code, replace all calls to `FlutterBlueMax` with the mockable instance, e.g.:  
`FlutterBlueMax.isScanning` --> `bluePlusMockable.isScanning`  
`FlutterBlueMax.startScan` --> `bluePlusMockable.startScan`  
`FlutterBlueMax.scanResults` --> `bluePlusMockable.scanResults`  
etc.

## Example

Detailed example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).
