# Blue Max Bluetooth workbench

A Material 3 example for exploring Bluetooth peripherals on Android, iOS, macOS, Linux and the web.
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
| Web | `flutter run -d chrome` | Browser device chooser and GATT for the services listed below; no L2CAP, RSSI, MTU requests or bonding. |

- Android: install the Android SDK and JDK (CI uses JDK 21), enable USB debugging and grant Bluetooth permissions; Android 7–11 also needs location permission/services for scanning.
- iOS: build on macOS with Xcode and select a development team in `ios/Runner.xcodeproj` for a physical device; start Simulator with `open -a Simulator`.
- macOS: install Xcode and allow Bluetooth access when prompted.
  Release builds failed with `Class with illegal cid` in Flutter 3.47.2 and 3.47.7; debug builds work ([matching Flutter issue](https://github.com/flutter/flutter/issues/191575)).
- Linux: build on Linux with Clang, CMake, Ninja, pkg-config and GTK 3 development libraries; Bluetooth requires BlueZ and a usable adapter.
- Web: use a browser with [Web Bluetooth support](https://developer.chrome.com/docs/capabilities/bluetooth) over HTTPS or localhost; **Start scan** opens the browser's device chooser.

The table describes implementation support, not completed hardware validation on every platform.
L2CAP controls are hidden on Linux and web.
On Android below version 10, L2CAP calls report an unsupported-operation error that the sample catches and displays.

### Web service access

As in the original example, the chooser requests access to Battery (`180F`), Device Information (`180A`), Generic Access (`1800`) and Nordic UART (`6E400001-B5A3-F393-E0A9-E50E24DCCA9E`).
Browser permissions restrict GATT access to these services: connecting to a device does not grant access to all of its services.
If none of the device's services are accessible, discovery can fail with `NotFoundError: No Services found in device` even though the connection succeeded.
For a custom service, add its UUID to `webOptionalServices` in [the scan call](lib/app/workbench_controller.dart), rebuild, then select the device again through **Start scan** to request access.

## Use the app

- **Devices:** scan or choose a browser device, connect, then open **GATT** to discover services, read/write characteristics and descriptors, or subscribe to notifications.
  Native platforms also expose advertisement data, RSSI and system-connected devices; Android adds bonding and MTU requests.
  On native platforms, **Track advertisements** in a device's **Advertisement** card scans only that device and keeps its latest 200 advertisements with RSSI, intervals and payload changes; the history can be filtered by text, changed payloads or parsed values.
- **Parsers:** define how manufacturer or service data is read as named values, optionally bound to one device; parsed values appear below the raw data and in the tracker history.
  Parsers are saved locally (shared preferences, browser local storage on web); first launches start with the status and sensor frames of the FBM test dongle firmware (manufacturer data `0xFFFF`), which **Add test dongle parsers** restores.
- **L2CAP:** on supported platforms, connect to a peer, open its **L2CAP** tab and enter the remote server's PSM.
  **Local server** accepts incoming channels and displays its assigned PSM.
  Peer discovery and PSM exchange must be provided separately; starting this server does not advertise a GATT peripheral.
  Channels have separate hex/UTF-8 editors, TX/RX counters, buffered reads, test traffic and a history of the latest 200 receive entries.
  Closing a channel retains its diagnostics until the device session resets; received chunks are not application message boundaries.
- **Activity:** search, copy or clear the latest 500 log entries, including the original errors when an operation fails.

The layout adapts to phones and desktops, supports light/dark themes and keeps Bluetooth sessions across workspace navigation.

## Download builds from GitHub Actions

The [Build example downloads](../../../.github/workflows/example_build.yml) workflow builds all five supported targets with Flutter 3.47.7 and retains downloads for 14 days.
Pull requests that change the packages or this workflow run all five builds, formatting checks, package:lint analysis, the native test suite and the two Chrome scenarios.
It produces Actions artifacts rather than GitHub Releases or pub.dev packages.

To build a branch without an open pull request before the workflow is on the default branch, check out that branch and deliberately push a new `example-test/` tag:

```sh
git tag example-test/my-build HEAD
git push origin refs/tags/example-test/my-build
```

Use a unique tag for each build; the tag builds its exact commit on all five platforms.
For branches without an open pull request, ordinary pushes do not trigger this workflow.
Once the workflow exists on the default branch, **Actions → Build example downloads → Run workflow** also lets you choose a branch and either `all` or one platform ([GitHub instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)).
After the run, download files from **Artifacts** or the links in the job summaries.

| Platform | Download | Usage |
| --- | --- | --- |
| Android | `blue-max-android-release.apk` | Install on an Android device; the release APK uses a debug signing key. |
| iOS Simulator | `blue-max-ios-simulator-arm64-debug.tar.gz` | Extract `Runner.app` and install it in an Apple Silicon iOS Simulator. |
| macOS | `blue-max-macos-arm64-debug.tar.gz` | Extract `Blue Max.app` and open it on an Apple Silicon Mac. |
| Linux | `blue-max-linux-x64-release.tar.gz` | Extract the complete `bundle` directory and run `bundle/flutter_blue_max_example`. |
| Web | `blue-max-web-release.tar.gz` | Extract and serve the `web` directory over localhost or HTTPS. |

The macOS app is ad-hoc signed, not notarized, and uses debug mode because of the release compiler failure noted above.
The Android signing key changes between fresh CI runners, so replacing an earlier build may require uninstalling it first.
The iOS artifact is for Simulator, not physical iPhones.
Linux needs GTK 3 and BlueZ; keep the bundle's `lib` and `data` directories beside the executable.

With an iOS Simulator booted, install the extracted app:

```sh
xcrun simctl install booted Runner.app
```

For web, run this from the directory containing the extracted `web` folder, then open <http://localhost:8080> in a compatible browser:

```sh
python3 -m http.server 8080 --bind 127.0.0.1 --directory web
```

Opening `index.html` directly from the filesystem does not provide the required web origin.

## Verification

From the example directory:

```sh
flutter analyze
flutter test
flutter test --platform chrome test/scenarios/workbench_test.dart --plain-name 'web:'
```

Tests execute the production example in `lib/` and the public `flutter_blue_max` API, replacing only platform I/O with an in-memory fake.
They cover the original sample workflows, including browser GATT, phone/desktop navigation and L2CAP diagnostics, but do not replace hardware testing.
