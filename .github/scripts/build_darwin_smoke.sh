#!/usr/bin/env bash
set -euo pipefail

# Build the published Darwin implementation without the example's SDK or plugin constraints.
# Usage: build_darwin_smoke.sh <flutter-sdk> <spm|pods> <ios|macos>
flutter_sdk="${1:?Flutter SDK path required}"
integration="${2:?spm or pods required}"
platform="${3:?ios or macos required}"
case "$integration" in spm) use_spm=true ;; pods) use_spm=false ;; *) exit 2 ;; esac
case "$platform" in ios|macos) ;; *) exit 2 ;; esac
repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
smoke_dir="$(mktemp -d)"
trap 'rm -rf "$smoke_dir"' EXIT
flutter="$flutter_sdk/bin/flutter"
"$flutter" create --platforms="$platform" --project-name=darwin_smoke --no-pub "$smoke_dir"
cat > "$smoke_dir/pubspec.yaml" <<EOF
name: darwin_smoke
publish_to: none
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_max_darwin:
    path: $repo_dir/packages/flutter_blue_max_darwin
dependency_overrides:
  flutter_blue_max_platform_interface:
    path: $repo_dir/packages/flutter_blue_max_platform_interface
flutter:
  uses-material-design: true
  config:
    enable-swift-package-manager: $use_spm
EOF
# Avoid template dev-dependencies, and use an app that retains the plugin registrant.
cat > "$smoke_dir/lib/main.dart" <<'EOF'
import 'package:flutter/material.dart';
void main() => runApp(const MaterialApp(home: Text('Darwin plugin smoke build')));
EOF
cd "$smoke_dir"
"$flutter" pub get
if [[ "$platform" == ios ]]; then
  "$flutter" build ios --simulator --debug --no-codesign --no-pub
else
  "$flutter" build macos --debug --no-pub
fi
if [[ "$integration" == pods ]]; then
  test -f "$platform/Podfile.lock"
  /usr/bin/grep -q flutter_blue_max_darwin "$platform/Podfile.lock"
else
  test -d "$platform/Flutter/ephemeral/Packages/.packages/flutter_blue_max_darwin"
fi
