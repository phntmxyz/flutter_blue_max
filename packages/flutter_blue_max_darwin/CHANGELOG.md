## 6.1.0
* Return the macOS host controller name from `adapterName`, or an empty string when no controller/name is available (previously the constant "Mac Bluetooth Adapter").
* Reply once to `getAdapterName` and `isSupported` method calls on iOS and macOS.
* Support both pre-3.41 and current Flutter Swift Package Manager engine layouts, and link IOBluetooth on macOS through SPM and CocoaPods.
* Isolate callbacks of the old native BLE session across hot restart and wait for the replacement manager to start.
* Retire L2CAP listeners on hot restart.
* Keep a cancelled pending connect from timing out. Both connect and disconnect report `connectionCanceled`.
* Reuse the instance id when a characteristic is discovered again.
* Report the written value of a descriptor.
* Send no value when a read ends in an ATT error, so the read fails with the ATT error instead of a timeout.
* Throw `UnsupportedError` from `turnOn`, because apps cannot turn Bluetooth on on iOS and macOS.
* Deliver `setOptions` and `setLogLevel` before the central manager is created.
* Document the public API.

## 6.0.0
* First public release as `flutter_blue_max_darwin` (fork of `flutter_blue_plus_darwin`). Version numbers below 6.0.0 refer to the original FlutterBluePlus history and are not published under this name.
* Add L2CAP CoC support (client & server)
  * writes are queued per channel and drained on `HasSpaceAvailable`; partial `NSOutputStream` writes no longer drop bytes
  * L2CAP connected/closed events are surfaced to Dart
  * works around several CoreBluetooth L2CAP defects (channel-close cascade, stale channel state) — see the L2CAP section of the README

## 4.0.1
* fix unrecognized selector sent to instance (regression from 4.0.0)

## 4.0.0
* Use bytes instead of hex for platform communication (#1130)

## 3.0.0
* Update platform interface version to 3.0.0

## 2.0.1
* Add log color

## 2.0.0
* Combine the packages previously published as flutter_blue_max_ios and flutter_blue_max_macos
* Add support for Swift Package Manager
* Replace void return types with bool return types
