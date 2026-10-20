# Blue Max Bluetooth workbench

A Material 3 example for exploring real Bluetooth peripherals on Android, iOS and macOS.
It uses the local packages in this repository through `pubspec_overrides.yaml`.

## Run

Use the Flutter 3.47.7 Puro environment from this directory:

```sh
puro -e 3.47.7 flutter pub get
puro -e 3.47.7 flutter run -d macos
```

For Android or a physical iPhone, select the device reported by:

```sh
puro -e 3.47.7 flutter devices
puro -e 3.47.7 flutter run -d <device-id>
```

Select your development team in Xcode before running on a physical iPhone.
The iOS Simulator can validate layout and builds, but cannot test Bluetooth communication.

## Toolchain and minimum versions

| Component | Example configuration |
| --- | --- |
| Flutter / Dart | 3.47.7 / 3.13.5 |
| Android Gradle Plugin / Gradle | 9.4.1 / 9.6.0 |
| Kotlin | 2.4.0, with AGP built-in Kotlin |
| Java | JDK 17 or newer; app bytecode targets Java 17 |
| Android compile / target SDK | 34 / 34 |
| Android minimum OS | API 24, Android 7.0 |
| Android L2CAP minimum OS | API 29, Android 10 |
| Apple dependency manager | Swift Package Manager |
| iOS minimum OS | 15.0 |
| macOS minimum OS | 12.0 |

`compileSdk 34` is the lowest version accepted by the current plugin and Flutter embedding's AndroidX dependencies.
An API 33 build fails AAR metadata checks; API 34 builds successfully.
AGP uses its own newer SDK Build Tools independently of the compile SDK.
The example targets API 34 to match this compile SDK; this is a local diagnostic app, not a Play Store submission configuration.
Flutter 3.47 requires `android.newDsl=false` because its Gradle integration still uses the legacy Variant API.
Kotlin is built into AGP; the settings plugin declaration selects Flutter's Kotlin version without applying the legacy Kotlin Android plugin to the app.

The Apple projects use Flutter's generated Swift packages and have no CocoaPods integration.
The Darwin plugin declares Flutter's `FlutterFramework` package dependency.
The example's OS minimums follow Flutter 3.47; the plugin packages retain their existing OS minimums.

## Workspaces

- **Devices:** scan for 15 seconds, pull to refresh, filter by name, identifier or service UUID, and inspect advertisements and signal strength.
  The discovery header also shows this device's local Bluetooth name when available.
  System-connected devices are queried on each scan, including peers connected through another app.
  As in the original example, Apple system-device lookup uses the Battery Service UUID (`180F`).
  Pending connections can be cancelled; broadcast-only advertisements cannot be connected.
  RSSI is read after connecting, and the Android adapter banner can request that Bluetooth be enabled.
  Connected devices remain accessible above the result list when a new scan starts.
  Select a device, connect, then choose **GATT** or **L2CAP** in its inspector.
  GATT exposes service discovery, characteristic/descriptor reads and writes, and notifications.
  Readable characteristics are read back after writing or changing subscriptions.
  Direct CCCD writes remain available, although the platform may reject them; Subscribe is the portable notification control.
  L2CAP opens a channel to that device's server using its PSM and only shows that device's outgoing channels.
  The PSM form is available after connecting; GATT service discovery is not required unless the peer uses GATT to publish its PSM.
  Android also exposes bonding and MTU requests.
- **Local server:** prepare this device to accept incoming L2CAP channels, independently of the selected peripheral.
  Starting the server only begins listening; it does not mean another device is connected.
  The screen distinguishes waiting for a peer from accepted channels and explains the separate discovery/PSM exchange requirement.
  Each channel has its own payload editor, TX/RX byte counters, latest received chunk and bounded receive history.
  Both incoming and outgoing channels expose buffered reads, a patterned 10 KB test write and a 20 × 1 KB burst.
  Buffered reads may repeat data already delivered by the stream, so they are labelled separately and do not increment the stream RX counter.
  The burst submits concurrent public-API calls; the library controls their native serialization.
  Failed channel opens are retried once, reconnecting the original peer if necessary.
  Channel identity includes both the peer and PSM.
- **Activity:** search and copy the most recent 500 log entries, including native diagnostics and payload previews.

The desktop layout keeps the device list beside the inspector.
Phones use a detail page and bottom navigation.
The header switches between light and dark themes.
Bluetooth sessions survive navigation between workspaces.
Hex input accepts complete byte pairs with optional whitespace; UTF-8 input sends encoded text.
Invalid payloads and PSMs are rejected before reaching the plugin.

## Source layout

`lib/main.dart` starts the application.
The remaining files are grouped by responsibility:

| Directory | Responsibility |
| --- | --- |
| `lib/app/` | App shell and Bluetooth session lifecycle |
| `lib/devices/` | Scan results, system devices, connection and advertisement inspection |
| `lib/gatt/` | Characteristics, subscriptions and descriptors |
| `lib/l2cap/` | Device channels, local server, transfers and receive history |
| `lib/activity/` | Session log search, copy and clearing |
| `lib/shared/` | Cards and validated payload input/formatting |

## Original example feature parity

The baseline is commit `4d0ca15`, before the example refresh.
The table tracks the original user-facing operations, including its L2CAP diagnostic controls.
Widget and controller tests execute the production example and public plugin API with native I/O faked.
They do not validate radio behavior or operating-system permission dialogs.

| Original capability | Current location | Automated coverage |
| --- | --- | --- |
| Adapter state and Android Turn On | App header/banner | Adapter transition and Android button |
| Scan, stop, pull to refresh | Devices | All three actions |
| System-connected devices | Devices → Connected to the system | Connect without an advertisement |
| Connect, cancel, disconnect | Device inspector | Pending cancellation; disconnect cleanup |
| Advertisement data, including appearance | Device → Advertisement | Appearance and broadcast-only connection guard |
| RSSI and MTU | Device header | Automatic RSSI; MTU requires Android hardware validation |
| Service discovery | Device → GATT | Discover and expand a service |
| Characteristic read/write | GATT characteristic | Both write modes, read-back and payload validation |
| Subscribe/unsubscribe | GATT characteristic | Both transitions and read-back |
| Descriptor read/write, including CCCD control | GATT descriptor | Ordinary descriptor read/write; direct CCCD control is reachable |
| L2CAP server start/stop and security choice | Local server | Lifecycle, incoming channel and shutdown cleanup |
| L2CAP client open/close | Device → L2CAP | Per-peer channels, closure cleanup and reconnect/retry |
| L2CAP send and live receive | Channel card | Writes, per-peer RX/TX counts and error handling |
| Buffered L2CAP read | Channel → Read buffered data | Peer routing and no double-counting |
| Large payload and burst | Channel → Send 10 KB / Burst 20×1 KB | Payload content/size, queued completion and partial failure |
| Receive history and RX count | Channel → Receive history | Bounded history and stream/read distinction |
| Logs and Clear | Activity | Bounded logging; search/copy/clear available in UI |

## Hardware checks

### GATT peripheral, including a BLE lamp

1. Turn on Bluetooth, start a scan and grant the requested Bluetooth permissions.
   On Android 7–11, scanning also needs location permission and location services.
2. Select the peripheral and connect.
3. Discover services and expand a service and characteristic.
4. Read a readable characteristic and check the hex/UTF-8 display.
5. Subscribe to a characteristic that supports notifications and trigger a change on the peripheral.
6. Disconnect, reconnect and discover services again.

A lamp does not need to visibly change for scanning, connection and service discovery to be useful tests.
Controlling brightness or power requires the manufacturer's protocol and may require provisioning or authentication.
Only send payloads whose meaning you know for that peripheral.

### L2CAP peer

A GATT or mesh lamp does not necessarily provide an LE credit-based L2CAP service.
Use a peer with a known L2CAP server/client implementation for this test.

1. Open **Local server**, start listening and copy the PSM assigned by the operating system.
2. Configure the peer's L2CAP client with this device and PSM.
   The example does not advertise a GATT service or publish the PSM through GATT; peer discovery and PSM exchange must be provided separately.
3. Send a known payload from the peer and check the incoming channel, RX counter and bytes.
4. Send a reply from the channel's editor and verify the exact bytes on the peer.
5. Close the channel from the peer and verify that it disappears.
6. Stop and restart the server, using the newly assigned PSM.

To test the outgoing path, connect to a discoverable GATT peripheral that also exposes an L2CAP server, then select **L2CAP** in that device's inspector and enter the remote PSM.
The Apple client follows the remote server's encryption requirement; Android exposes the secure/insecure choice.
Received values are stream chunks, not application message boundaries.

## Verification

```sh
puro -e 3.47.7 flutter analyze
puro -e 3.47.7 flutter test
puro -e 3.47.7 flutter build apk --debug
puro -e 3.47.7 flutter build ios --simulator --debug
puro -e 3.47.7 flutter build macos --debug
```

Tests import the production files in `lib/` and run the actual `flutter_blue_max` API.
Only the native platform interface is replaced by an in-memory fake.
Controller tests cover peer isolation, disconnect cleanup, pending server startup, error recovery and bounded logs.
Robot tests exercise desktop and phone navigation, GATT operations, payload validation and server lifecycle.
They also verify the connection prerequisite for outgoing L2CAP, per-device channel/input isolation,
and the transition from a listening server to an accepted incoming channel.
They do not replace hardware validation of the Android or CoreBluetooth implementations.

### macOS release compiler limitation

With Flutter 3.47.2 and 3.47.7, this app's macOS release build currently aborts in Flutter's AOT snapshot generator with `Class with illegal cid` for `_window_macos.dart` / `_Rect`.
This matches the open [Flutter issue #191575](https://github.com/flutter/flutter/issues/191575).
The macOS debug build and real Bluetooth scanning work; use `puro -e 3.47.7 flutter run -d macos` for hardware testing.
No application-code or SDK patches are applied to hide the compiler failure.
