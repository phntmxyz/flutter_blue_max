## 5.0.3
* First public release as `flutter_blue_max_android` (fork of `flutter_blue_plus_android`). Version numbers below 5.0.0 refer to the original FlutterBluePlus history.
* Add L2CAP CoC support (client & server)
  * blocking socket connect/write run on a background executor instead of the main thread
  * read buffers are sized from the socket MTU so large SDUs are not truncated
  * channels are keyed by device + PSM so multiple devices can share a PSM
  * L2CAP connected/closed events are surfaced to Dart

## 4.0.5
* Fixes to check for location services when plugin is called from a service

## 4.0.3
* Added option to disable Location Services check

## 4.0.2
* Fix compile error

## 4.0.1
* Fix compile error

## 4.0.0
* Use bytes instead of hex for platform communication (#1130)
* Check if Android location services are enabled when doing scan (#1167)

## 3.0.0
* Add option to provide pairing PIN to `createBond` (#1119)

## 2.0.1
* Add log color

## 2.0.0
* Replace void return types with bool return types

## 1.35.0
* Split from `flutter_blue_max` as a federated implementation
