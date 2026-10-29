import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';

enum AdvertisementSource(final String label) {
  manufacturer('Manufacturer data'),
  service('Service data'),
}

/// [size] is null for variable-width types, which read [AdvertisementField.length] bytes.
enum AdvertisementFieldType(final String label, final int? size) {
  uint8('uint8', 1),
  int8('int8', 1),
  uint16le('uint16 LE', 2),
  uint16be('uint16 BE', 2),
  uint24le('uint24 LE', 3),
  uint24be('uint24 BE', 3),
  int16le('int16 LE', 2),
  int16be('int16 BE', 2),
  uint32le('uint32 LE', 4),
  uint32be('uint32 BE', 4),
  int32le('int32 LE', 4),
  int32be('int32 BE', 4),
  float32le('float32 LE', 4),
  float32be('float32 BE', 4),
  hex('Hex', null),
  ascii('ASCII', null),
}

/// One value at a fixed offset of a manufacturer or service data payload.
class const AdvertisementField(
  final String name,
  final int offset,
  final AdvertisementFieldType type, {
  final int length = 1,
  final double scale = 1,
  final String unit = '',
}) {
  /// Throws a [FormatException] for stored data that no longer describes a field.
  factory fromJson(Map<String, dynamic> json) {
    try {
      return AdvertisementField(
        json['name'] as String,
        json['offset'] as int,
        AdvertisementFieldType.values.byName(json['type'] as String),
        length: json['length'] as int,
        scale: (json['scale'] as num).toDouble(),
        unit: json['unit'] as String,
      );
    } on Object catch (error) {
      throw FormatException('Invalid parser field: $error');
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'offset': offset,
    'type': type.name,
    'length': length,
    'scale': scale,
    'unit': unit,
  };

  int get size => type.size ?? length;

  /// Short payloads are reported per field, so one malformed frame never hides the others.
  String format(List<int> bytes) {
    if (offset < 0 || size < 1 || offset + size > bytes.length) {
      return 'too short (${bytes.length} B)';
    }
    final slice = bytes.sublist(offset, offset + size);
    if (type == AdvertisementFieldType.hex) {
      return PayloadCodec.hex(slice);
    }
    if (type == AdvertisementFieldType.ascii) {
      return PayloadCodec.text(slice);
    }
    final data = ByteData.sublistView(Uint8List.fromList(slice));
    final num value = switch (type) {
      AdvertisementFieldType.hex || AdvertisementFieldType.ascii => throw StateError('$type is not numeric'),
      AdvertisementFieldType.uint8 => data.getUint8(0),
      AdvertisementFieldType.int8 => data.getInt8(0),
      AdvertisementFieldType.uint16le => data.getUint16(0, Endian.little),
      AdvertisementFieldType.uint16be => data.getUint16(0),
      AdvertisementFieldType.int16le => data.getInt16(0, Endian.little),
      AdvertisementFieldType.int16be => data.getInt16(0),
      AdvertisementFieldType.uint24le => slice[0] | slice[1] << 8 | slice[2] << 16,
      AdvertisementFieldType.uint24be => slice[0] << 16 | slice[1] << 8 | slice[2],
      AdvertisementFieldType.uint32le => data.getUint32(0, Endian.little),
      AdvertisementFieldType.uint32be => data.getUint32(0),
      AdvertisementFieldType.int32le => data.getInt32(0, Endian.little),
      AdvertisementFieldType.int32be => data.getInt32(0),
      AdvertisementFieldType.float32le => data.getFloat32(0, Endian.little),
      AdvertisementFieldType.float32be => data.getFloat32(0),
    };
    final scaled = value * scale;
    final text = value is int && scale == scale.roundToDouble()
        ? '${scaled.round()}'
        : scaled.toStringAsFixed(_decimals);
    return unit.isEmpty ? text : '$text $unit';
  }

  /// Enough decimals to show one step of the scale: 0.1 → 1, 0.005 and 1/256 → 3.
  /// Unscaled floats keep two.
  int get _decimals {
    if (scale == 1) {
      return 2;
    }
    // The epsilon absorbs rounding, e.g. -log10(0.001) = 2.9999999999999996.
    return (-log(scale.abs()) / ln10 - 1e-9).ceil().clamp(1, 6);
  }
}

/// Reads named values from advertisements whose source and byte pattern match.
/// Parsers are global unless bound to [device]; the pattern keeps vendors apart.
class const AdvertisementParser({
  required final String name,
  required final AdvertisementSource source,

  /// Required for [AdvertisementSource.manufacturer].
  final int? companyId,

  /// Required for [AdvertisementSource.service].
  final Guid? serviceUuid,

  /// Bytes the payload must contain at [matchOffset], e.g. a frame type.
  final List<int> match = const [],
  final int matchOffset = 0,
  final DeviceIdentifier? device,
  required final List<AdvertisementField> fields,
}) {
  /// Throws a [FormatException] for stored data that no longer describes a parser.
  factory fromJson(Map<String, dynamic> json) {
    try {
      final serviceUuid = json['serviceUuid'] as String?;
      final device = json['device'] as String?;
      return AdvertisementParser(
        name: json['name'] as String,
        source: AdvertisementSource.values.byName(json['source'] as String),
        companyId: json['companyId'] as int?,
        serviceUuid: serviceUuid == null ? null : Guid(serviceUuid),
        match: List<int>.from(json['match'] as List),
        matchOffset: json['matchOffset'] as int,
        device: device == null ? null : DeviceIdentifier(device),
        fields: [
          for (final field in json['fields'] as List) AdvertisementField.fromJson(field as Map<String, dynamic>),
        ],
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid parser: $error');
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'source': source.name,
    'companyId': companyId,
    'serviceUuid': serviceUuid?.str128,
    'match': match,
    'matchOffset': matchOffset,
    'device': device?.str,
    'fields': [for (final field in fields) field.toJson()],
  };

  /// Where and when the parser reads, for parser lists.
  String get summary => [
    switch (source) {
      AdvertisementSource.manufacturer => 'Manufacturer 0x${companyId!.toRadixString(16)}',
      AdvertisementSource.service => 'Service data $serviceUuid',
    },
    if (match.isNotEmpty) 'match ${PayloadCodec.hex(match)} at $matchOffset',
    '${fields.length} ${fields.length == 1 ? 'field' : 'fields'}',
    if (device == null) 'All devices' else 'Only ${device!.str}',
  ].join(' · ');

  bool appliesTo(DeviceIdentifier remoteId) => device == null || device == remoteId;

  /// Whether [data] carries this parser's source, regardless of the byte pattern.
  bool readsFrom(AdvertisementData data) => switch (source) {
    AdvertisementSource.manufacturer => data.manufacturerData.containsKey(companyId),
    AdvertisementSource.service => data.serviceData.containsKey(serviceUuid),
  };

  /// Returns one line per field, or nothing if this payload is not meant for this parser.
  List<String> read({int? companyId, Guid? serviceUuid, required List<int> bytes}) {
    final sourceMatches = switch (source) {
      AdvertisementSource.manufacturer => companyId != null && companyId == this.companyId,
      AdvertisementSource.service => serviceUuid != null && serviceUuid == this.serviceUuid,
    };
    if (!sourceMatches || !_matches(bytes)) {
      return [];
    }
    return [for (final field in fields) '$name · ${field.name}: ${field.format(bytes)}'];
  }

  bool _matches(List<int> bytes) {
    if (matchOffset + match.length > bytes.length) {
      return false;
    }
    for (var i = 0; i < match.length; i++) {
      if (bytes[matchOffset + i] != match[i]) {
        return false;
      }
    }
    return true;
  }
}
