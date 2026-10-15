import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hex supports pasted whitespace and round trips all byte values', () {
    expect(PayloadCodec.decode('00 a2\nFF\t10', hex: true), [0, 162, 255, 16]);
    final bytes = List.generate(256, (i) => i);
    expect(PayloadCodec.decode(PayloadCodec.hex(bytes), hex: true), bytes);
  });

  test('malformed hex is rejected instead of partially transmitted', () {
    for (final input in ['1', '001', 'GG', '0x01', '01,02', '-1']) {
      expect(() => PayloadCodec.decode(input, hex: true), throwsFormatException);
    }
  });

  test('UTF-8 preserves multibyte text and binary previews tolerate invalid UTF-8', () {
    expect(PayloadCodec.decode('Grüße', hex: false), [71, 114, 195, 188, 195, 159, 101]);
    expect(PayloadCodec.text([0xff, 65]), '\uFFFDA');
  });

  test('PSM accepts decimal and hexadecimal and rejects invalid values', () {
    expect(PayloadCodec.psm(' 129 '), 129);
    expect(PayloadCodec.psm('0x81'), 129);
    for (final value in ['', '0', '-1', '65536', '12.3', 'hello']) {
      expect(() => PayloadCodec.psm(value), throwsFormatException);
    }
  });
}
