# Blue Max Bluetooth workbench

A Material 3 example for exploring real Bluetooth peripherals on Android, iOS, macOS and Linux.
It uses the local packages in this repository through `pubspec_overrides.yaml`.

## Run

Tested with **Flutter 3.47.7 / Dart 3.13.5**.
The minimum declared in `pubspec.yaml` is **Flutter 3.47.0 / Dart 3.13.0**.
From the repository root:

```sh
cd packages/flutter_blue_max/example
flutter pub get
flutter devices
```

Replace `<device-id>` below with the ID from `flutter devices`.

| Platform | Start from the example directory | Current functionality |
| --- | --- | --- |
| Android 7+ | `flutter run -d <device-id>` | Scan, GATT, bonding and MTU requests; L2CAP client/server requires Android 10+. |
| iPhone / iPad, iOS 15+ | `flutter run -d <device-id>` | Scan, GATT and L2CAP client/server. |
| iOS Simulator | Start Simulator, then `flutter run -d <device-id>` | UI and build checks only; no real Bluetooth communication. |
| macOS 12+ | `flutter run -d macos --debug` | Scan, GATT and L2CAP client/server; use debug mode with the tested Flutter version. |
| Linux | `flutter run -d linux` | Scan and GATT backend; no L2CAP client/server. |
| Windows | Not available | No example runner or Windows Bluetooth backend. |
| Web | Not available | No example runner; a separate web backend exists, without L2CAP. |

- Android: install the Android SDK/JDK, enable USB debugging and grant Bluetooth permissions; Android 7–11 also needs location permission/services for scanning.
- iOS: build on macOS with Xcode and select a development team in `ios/Runner.xcodeproj` for a physical device; start Simulator with `open -a Simulator`.
- macOS: install Xcode and allow Bluetooth access when prompted.
- Linux: build on Linux with Clang, CMake, Ninja, pkg-config and GTK 3 development libraries; Bluetooth requires BlueZ and a usable adapter.

The table describes implementation support, not completed hardware validation on every platform.
Known UI limitation: L2CAP controls are still visible on Linux and older Android devices; unsupported calls show a dismissible error.

## Download builds from GitHub Actions

The [Build example downloads](../../../.github/workflows/example_build.yml) workflow runs manually through **Actions → Build example downloads → Run workflow**.
Select a branch and either `all` or one platform.
After the run, download the files from **Artifacts** or the links in the job summaries; downloads are retained for 14 days.
GitHub requires the workflow on the repository's default branch to show the **Run workflow** button.
See [GitHub's manual workflow instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

To test a branch before merging the workflow, check out that branch and deliberately push a new `example-test/` tag:

```sh
git tag example-test/my-build HEAD
git push origin refs/tags/example-test/my-build
```

Choose a unique tag name for each build.
These tags build all four platforms from the tagged commit; ordinary branch pushes do not start builds.
The [tag push trigger](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push) works with workflows that have not been merged into the default branch.

| Platform | Download | Usage |
| --- | --- | --- |
| Android | `blue-max-android-release.apk` | Install on an Android device; the sample uses debug-key signing for its release builds. |
| iOS Simulator | `blue-max-ios-simulator-arm64-debug.tar.gz` | Extract `Runner.app` and install it in an Apple Silicon iOS Simulator. |
| macOS | `blue-max-macos-arm64-debug.tar.gz` | Extract `Blue Max.app` and open it on an Apple Silicon Mac. |
| Linux | `blue-max-linux-x64-release.tar.gz` | Extract the complete `bundle` directory and run `bundle/flutter_blue_max_example`. |

The workflow pins Flutter 3.47.7 through `FLUTTER_VERSION`.
It builds the local package implementations from the selected checkout and does not publish packages or releases.
The existing `Publish Flutter Blue Plus…` workflows publish library packages to pub.dev when their version tags are pushed.
Windows and web are omitted because this sample has no runner for either platform.

The macOS download uses debug mode because of the [release compiler limitation](#macos-release-compiler-limitation) below.
It is ad-hoc signed rather than notarized; macOS may require approval in **System Settings → Privacy & Security** when opening a downloaded build.
The Android signing key is generated on each fresh runner, so installing a later build may require uninstalling the previous build first.
Linux needs GTK 3 and BlueZ on the target system; keep the bundle's `lib` and `data` directories beside the executable.
The iOS download is a simulator app, not an IPA for physical iPhones; no Apple signing secrets are required.

With an iOS Simulator booted, install the extracted app using:

```sh
xcrun simctl install booted Runner.app
```

## Toolchain and minimum versions

| Component | Example configuration |
| --- | --- |
| Flutter / Dart tested | 3.47.7 / 3.13.5 |
| Flutter / Dart minimum (`pubspec.yaml`) | 3.47.0 / 3.13.0 |
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
  RSSI is read after connecting and when reopening a connected device, and the Android adapter banner can request that Bluetooth be enabled.
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
  Each channel has its own payload editor, TX/RX byte counters, latest received chunk and a history of the latest 200 receive entries.
  Closing a channel keeps its history and counters visible, with transfer controls hidden; reopening the same peer/PSM continues that history.
  Both incoming and outgoing channels expose buffered reads, a patterned 10 KB test write and a 20 × 1 KB burst.
  Buffered reads may repeat data already delivered by the stream, so they are labelled separately and do not increment the stream RX counter.
  The burst submits concurrent public-API calls; the library controls their native serialization.
  Failed channel opens are retried once, reconnecting the original peer if necessary, unless the platform reports that the operation is unsupported.
  Unsupported operations show a dismissible explanation; the original error remains in Activity for diagnosis.
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
| Receive history and RX count | Channel → Receive history | 200 entries, stream/read distinction and retention after channel closure/reopening |
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
5. Close the channel from the peer and verify that its card says Closed, retains received data and hides transfer controls.
6. Stop and restart the server, using the newly assigned PSM.

To test the outgoing path, connect to a discoverable GATT peripheral that also exposes an L2CAP server, then select **L2CAP** in that device's inspector and enter the remote PSM.
The Apple client follows the remote server's encryption requirement; Android exposes the secure/insecure choice.
Received values are stream chunks, not application message boundaries.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
flutter build macos --debug
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
This matches [Flutter issue #191575](https://github.com/flutter/flutter/issues/191575).
The macOS debug build and real Bluetooth scanning work; use `flutter run -d macos --debug` for hardware testing.
No application-code or SDK patches are applied to hide the compiler failure.
