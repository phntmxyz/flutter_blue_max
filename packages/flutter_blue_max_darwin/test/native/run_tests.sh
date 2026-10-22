#!/usr/bin/env bash
set -euo pipefail

# Pass the Flutter SDK selected by Puro as the first argument.
flutter_sdk="${1:?Usage: bash test/native/run_tests.sh /path/to/flutter-sdk}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
source_dir="$test_dir/../../darwin/flutter_blue_max_darwin/Sources/flutter_blue_max_darwin"
framework_dir="$flutter_sdk/bin/cache/artifacts/engine/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$build_dir/modules" \
    -F "$framework_dir" -framework FlutterMacOS -framework Foundation -framework CoreBluetooth \
    -I "$source_dir/include/flutter_blue_max_darwin" \
    -Wl,-rpath,"$framework_dir" \
    "$source_dir/FlutterBlueMaxPlugin.m" "$test_dir/restart_test.m" \
    -o "$build_dir/restart_test"
"$build_dir/restart_test"
