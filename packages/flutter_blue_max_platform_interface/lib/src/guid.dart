// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A 16, 32 or 128 bit Bluetooth UUID.
class Guid {
  /// Creates a [Guid] from a hex string, with or without dashes. An empty string results in the all-zero 128 bit UUID.
  Guid(String input) : bytes = _toBytes(input);

  /// Creates the all-zero 128 bit [Guid].
  Guid.empty() : bytes = List.filled(16, 0);

  /// Creates a [Guid] from 2, 4 or 16 bytes.
  Guid.fromBytes(this.bytes) : assert(_checkLen(bytes.length), "GUID must be 16, 32, or 128 bit.");

  /// Creates a [Guid] from a hex string, same as the default constructor.
  Guid.fromString(String input) : bytes = _toBytes(input);

  /// The raw bytes of the UUID, 2, 4 or 16 of them.
  final List<int> bytes;

  /// Parses [input], returns null if it is null or empty.
  static Guid? parse(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    } else {
      return Guid(input);
    }
  }

  static List<int> _toBytes(String input) {
    if (input.isEmpty) {
      return List.filled(16, 0);
    }

    final String hex = input.replaceAll("-", "");

    final List<int>? bytes = _tryHexDecode(hex);
    if (bytes == null) {
      throw FormatException("GUID not hex format: $hex");
    }

    _checkLen(bytes.length);

    return bytes;
  }

  static bool _checkLen(int len) {
    if (!(len == 16 || len == 4 || len == 2)) {
      throw FormatException("GUID must be 16, 32, or 128 bit, yours: ${len * 8}-bit");
    }
    return true;
  }

  /// The 128 bit representation, the Bluetooth base UUID is used to expand 16 and 32 bit UUIDs.
  String get str128 {
    if (bytes.length == 2) {
      // 16-bit uuid
      return "0000${_hexEncode(bytes)}-0000-1000-8000-00805f9b34fb".toLowerCase();
    }
    if (bytes.length == 4) {
      // 32-bit uuid
      return "${_hexEncode(bytes)}-0000-1000-8000-00805f9b34fb".toLowerCase();
    }
    // 128-bit uuid
    final String one = _hexEncode(bytes.sublist(0, 4));
    final String two = _hexEncode(bytes.sublist(4, 6));
    final String three = _hexEncode(bytes.sublist(6, 8));
    final String four = _hexEncode(bytes.sublist(8, 10));
    final String five = _hexEncode(bytes.sublist(10, 16));
    return "$one-$two-$three-$four-$five".toLowerCase();
  }

  /// The shortest representation, 16 or 32 bit for UUIDs based on the Bluetooth base UUID.
  String get str {
    final bool starts = str128.startsWith("0000");
    final bool ends = str128.contains("-0000-1000-8000-00805f9b34fb");
    if (starts && ends) {
      // 16-bit
      return str128.substring(4, 8);
    }
    if (ends) {
      // 32-bit
      return str128.substring(0, 8);
    }
    // 128-bit
    return str128;
  }

  @override
  String toString() => str;

  @override
  bool operator ==(Object other) => other is Guid && str128 == other.str128;

  @override
  int get hashCode => str128.hashCode;

  @Deprecated("use str128 instead")
  String get uuid128 => str128;

  @Deprecated("use str instead")
  String get uuid => str;
}

String _hexEncode(List<int> numbers) {
  return numbers.map((n) => (n & 0xFF).toRadixString(16).padLeft(2, "0")).join();
}

List<int>? _tryHexDecode(String hex) {
  final List<int> numbers = [];
  for (int i = 0; i < hex.length; i += 2) {
    final String hexPart = hex.substring(i, i + 2);
    final int? num = int.tryParse(hexPart, radix: 16);
    if (num == null) {
      return null;
    }
    numbers.add(num);
  }
  return numbers;
}
