## 6.0.0
* First public release as `flutter_blue_max_darwin` (fork of `flutter_blue_plus_darwin`). Version numbers below 6.0.0 refer to the original FlutterBluePlus history and are not published under this name.
* Add L2CAP CoC support (client & server)
  * writes are queued per channel and drained on `HasSpaceAvailable`; partial `NSOutputStream` writes no longer drop bytes
  * L2CAP connected/closed events are surfaced to Dart
  * works around several CoreBluetooth L2CAP defects (channel-close cascade, stale channel state) — see L2CAP_README.md

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
