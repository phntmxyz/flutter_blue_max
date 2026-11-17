/// Parses the PSM supplied by the remote server, in decimal or with a 0x prefix.
int parsePsm(String input) {
  final value = int.tryParse(input.trim());
  if (value == null || value < 1 || value > 65535) {
    throw const FormatException('Enter a PSM from 1 to 65535, in decimal or 0x hexadecimal.');
  }
  return value;
}
