import 'package:flutter_blue_max_example/l2cap/psm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PSM accepts decimal and hexadecimal and rejects invalid values', () {
    expect(parsePsm(' 129 '), 129);
    expect(parsePsm('0x81'), 129);
    for (final value in ['', '0', '-1', '65536', '12.3', 'hello']) {
      expect(() => parsePsm(value), throwsFormatException);
    }
  });
}
