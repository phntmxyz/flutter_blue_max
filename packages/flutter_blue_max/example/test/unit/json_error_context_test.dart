import 'dart:collection';

import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON model wrappers preserve the original error stack', () {
    final decoders = <Object Function(Map<String, dynamic>)>[
      AdvertisementParser.fromJson,
      RecordFormat.fromJson,
      AdvertisementField.fromJson,
      KnownService.fromJson,
      KnownCharacteristic.fromJson,
    ];
    for (final decode in decoders) {
      try {
        decode(_FailingMap());
        fail('Expected a format exception');
      } on FormatException catch (exception, stackTrace) {
        expect(exception.message, contains('decode failed'));
        expect(stackTrace.toString(), 'original decode stack');
      }
    }
  });
}

final class _FailingMap() extends MapBase<String, dynamic> {
  @override
  dynamic operator [](Object? key) =>
      Error.throwWithStackTrace(StateError('decode failed'), StackTrace.fromString('original decode stack'));
  @override
  void operator []=(String key, dynamic value) => throw UnsupportedError('read only');
  @override
  void clear() => throw UnsupportedError('read only');
  @override
  Iterable<String> get keys => const [];
  @override
  dynamic remove(Object? key) => throw UnsupportedError('read only');
}
