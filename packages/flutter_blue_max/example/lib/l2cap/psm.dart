/// The largest PSM of an LE credit-based channel, the only kind of L2CAP channel the plugin opens.
const maxPsm = 0xff;

const psmInputMessage = "Enter a PSM from 1 to $maxPsm, in decimal or 0x hexadecimal.";

/// Parses the PSM supplied by the remote server, in decimal or with a 0x prefix.
int parsePsm(String input) {
  final value = int.tryParse(input.trim());
  if (value == null || value < 1 || value > maxPsm) {
    throw const FormatException(psmInputMessage);
  }
  return value;
}
