# flutter_blue_max_platform_interface

A common platform interface for the [`flutter_blue_max`][1] plugin.

This interface allows platform-specific implementations of the `flutter_blue_max`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `flutter_blue_max`, extend
[`FlutterBlueMaxPlatform`][2] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`FlutterBlueMaxPlatform` by calling
`FlutterBlueMaxPlatform.instance = MyPlatformFlutterBlueMax()`.

# Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion
on why a less-clean interface is preferable to a breaking change.

[1]: ../flutter_blue_max
[2]: lib/flutter_blue_max_platform_interface.dart
