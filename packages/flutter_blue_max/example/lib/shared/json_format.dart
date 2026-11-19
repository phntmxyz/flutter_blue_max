/// Current list-envelope version shared by exported files and persisted libraries.
const jsonListVersion = 1;

/// Legacy envelopes omit their version. Reject newer formats before interpreting or overwriting their entries.
void checkJsonListVersion(Map<String, dynamic> json, {required String source}) {
  final version = json.containsKey('version') ? json['version'] : 0;
  if (version is! int || version < 0) {
    throw FormatException('The $source has an invalid format version.');
  }
  if (version > jsonListVersion) {
    throw FormatException('The $source uses a newer format (version $version). Update Blue Max before opening it.');
  }
}
