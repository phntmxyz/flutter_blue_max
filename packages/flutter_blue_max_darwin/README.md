# flutter_blue_max_darwin

The iOS and macOS implementation of [`flutter_blue_max`][1].

## Usage

This package is [endorsed][2], which means you can simply use `flutter_blue_max`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you
should add it to your `pubspec.yaml` as usual.

## Swift Package Manager

The plugin supports Swift Package Manager with Flutter 3.44 or newer through the generated `FlutterFramework` dependency.
The [example app](../flutter_blue_max/example/README.md) uses this integration on both iOS and macOS.

For an existing application, follow Flutter's [Swift Package Manager migration guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers).
The CocoaPods podspec remains available for applications using the older integration.

[1]: https://pub.dev/packages/flutter_blue_max
[2]: https://flutter.dev/to/endorsed-federated-plugin
