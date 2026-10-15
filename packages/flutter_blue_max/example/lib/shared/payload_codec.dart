import 'dart:convert';

/// Converts user-entered payloads without silently truncating malformed bytes.
abstract final class PayloadCodec {
  /// Accepts hexadecimal byte pairs, optionally separated by whitespace.
  static List<int> decode(String input, {required bool hex}) {
    if (!hex) {
      return utf8.encode(input);
    }
    final compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(compact)) {
      throw const FormatException('Use complete hex byte pairs, such as 01 A2 FF.');
    }
    return [for (var i = 0; i < compact.length; i += 2) int.parse(compact.substring(i, i + 2), radix: 16)];
  }

  /// Displays bytes in a form that can be pasted back into the hex editor.
  static String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();

  /// Keeps binary data readable without failing on invalid UTF-8.
  static String text(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

  /// Parses the PSM supplied by the remote server, in decimal or with a 0x prefix.
  static int psm(String input) {
    final value = int.tryParse(input.trim());
    if (value == null || value < 1 || value > 65535) {
      throw const FormatException('Enter a PSM from 1 to 65535, in decimal or 0x hexadecimal.');
    }
    return value;
  }
}
