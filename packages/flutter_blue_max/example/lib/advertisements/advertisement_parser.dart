import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';

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

  /// Null when every field sits at a fixed offset of the payload.
  final RecordFormat? records,
  final DeviceIdentifier? device,
  required final List<AdvertisementField> fields,
}) {
  /// Throws a [FormatException] for stored data that no longer describes a parser.
  factory fromJson(Map<String, dynamic> json) {
    final AdvertisementParser parser;
    try {
      final serviceUuid = json['serviceUuid'] as String?;
      final records = json['records'] as Map<String, dynamic>?;
      final device = json['device'] as String?;
      parser = AdvertisementParser(
        name: json['name'] as String,
        source: AdvertisementSource.values.byName(json['source'] as String),
        companyId: json['companyId'] as int?,
        serviceUuid: serviceUuid == null ? null : Guid(serviceUuid),
        match: List<int>.unmodifiable(json['match'] as List),
        matchOffset: json['matchOffset'] as int,
        records: records == null ? null : RecordFormat.fromJson(records),
        device: device == null ? null : DeviceIdentifier(device),
        fields: List<AdvertisementField>.unmodifiable([
          for (final field in json['fields'] as List) AdvertisementField.fromJson(field as Map<String, dynamic>),
        ]),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(FormatException('Invalid parser: $error'), stackTrace);
    }
    // The same rules as the editor, so imported and stored parsers render like hand-made ones.
    final companyId = parser.companyId;
    final hasSource = switch (parser.source) {
      AdvertisementSource.manufacturer => companyId != null && companyId >= 0 && companyId <= 0xffff,
      AdvertisementSource.service => parser.serviceUuid != null,
    };
    if (!hasSource) {
      throw FormatException('Invalid parser ${parser.name}: ${parser.source.label} needs a company ID or service UUID');
    }
    if (parser.matchOffset < 0 || parser.match.any((byte) => byte < 0 || byte > 0xff)) {
      throw FormatException('Invalid parser ${parser.name}: match ${parser.match} at ${parser.matchOffset}');
    }
    return parser;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'source': source.name,
    'companyId': companyId,
    'serviceUuid': serviceUuid?.str128,
    'match': match,
    'matchOffset': matchOffset,
    'records': records?.toJson(),
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
    ?records?.summary,
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
    final records = this.records;
    if (records == null) {
      return [for (final field in fields) '$name · ${field.name}: ${field.format(bytes)}'];
    }
    // A record type without a length byte is as large as its fields reach.
    final sizes = <int, int>{};
    for (final field in fields) {
      final record = field.record;
      if (record != null) {
        sizes[record] = max(sizes[record] ?? 0, field.offset + field.size);
      }
    }
    final (:values, :problem) = records.split(bytes, sizes);
    // Fields of records absent from this frame are left out: many sensors send one value per frame.
    return [
      for (final field in fields)
        if (values[field.record] != null) '$name · ${field.name}: ${field.format(values[field.record]!)}',
      if (problem != null) '$name · $problem',
    ];
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
  ascii('ASCII', null);

  /// Bit ranges are read from unsigned integers only.
  bool get unsigned => switch (this) {
    uint8 || uint16le || uint16be || uint24le || uint24be || uint32le || uint32be => true,
    _ => false,
  };
}

/// Width and byte order of a record's type.
enum RecordTypeFormat(final String label, final int size) {
  uint8('1 byte', 1),
  uint16le('2 bytes LE', 2),
  uint16be('2 bytes BE', 2);

  int read(List<int> bytes, int offset) => switch (this) {
    uint8 => bytes[offset],
    uint16le => bytes[offset] | bytes[offset + 1] << 8,
    uint16be => bytes[offset] << 8 | bytes[offset + 1],
  };

  String format(int type) => '0x${type.toRadixString(16).padLeft(size * 2, '0').toUpperCase()}';
}

/// Where a record states the size of its value.
enum RecordLength(final String label) {
  /// A length byte follows the type and counts the value.
  afterType('Type, length, value'),

  /// A length byte precedes the type and counts type and value, as in advertising data structures.
  beforeType('Length, type, value'),

  /// No length byte: the fields of a type define its size, as in BTHome.
  /// Splitting stops at a type without fields, because its size is unknown.
  implied('Type, value'),
}

/// A payload that continues as a sequence of type–length–value records, e.g. BTHome.
/// Fields then name their record type, so their position in the payload does not matter.
class const RecordFormat({
  /// Where the first record starts.
  final int offset = 0,
  final RecordTypeFormat type = RecordTypeFormat.uint8,
  final RecordLength length = RecordLength.afterType,
}) {
  /// Throws a [FormatException] for stored data that no longer describes a record format.
  factory fromJson(Map<String, dynamic> json) {
    final RecordFormat format;
    try {
      format = RecordFormat(
        offset: json['offset'] as int,
        type: RecordTypeFormat.values.byName(json['type'] as String),
        length: RecordLength.values.byName(json['length'] as String),
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(FormatException('Invalid record format: $error'), stackTrace);
    }
    if (format.offset < 0) {
      throw FormatException('Invalid record format: offset ${format.offset}');
    }
    return format;
  }

  Map<String, dynamic> toJson() => {'offset': offset, 'type': type.name, 'length': length.name};

  /// The value of each record type in [bytes], keeping the first of repeated types.
  /// [sizes] gives the value size per type for [RecordLength.implied].
  /// [problem] explains why splitting stopped before the end of the payload.
  ({Map<int, List<int>> values, String? problem}) split(List<int> bytes, Map<int, int> sizes) {
    final values = <int, List<int>>{};
    var position = offset;
    while (position < bytes.length) {
      final int recordType;
      final int start;
      final int size;
      switch (length) {
        case RecordLength.afterType:
          if (position + type.size + 1 > bytes.length) {
            return (values: values, problem: 'record header truncated at $position');
          }
          recordType = type.read(bytes, position);
          start = position + type.size + 1;
          size = bytes[position + type.size];
        case RecordLength.beforeType:
          // A zero length ends the records, as padding does in advertising data.
          if (bytes[position] == 0) {
            return (values: values, problem: null);
          }
          if (bytes[position] < type.size || position + 1 + type.size > bytes.length) {
            return (values: values, problem: 'record header truncated at $position');
          }
          recordType = type.read(bytes, position + 1);
          start = position + 1 + type.size;
          size = bytes[position] - type.size;
        case RecordLength.implied:
          if (position + type.size > bytes.length) {
            return (values: values, problem: 'record header truncated at $position');
          }
          recordType = type.read(bytes, position);
          start = position + type.size;
          final known = sizes[recordType];
          if (known == null) {
            return (values: values, problem: 'unknown record ${type.format(recordType)} at $position');
          }
          size = known;
      }
      if (start + size > bytes.length) {
        return (values: values, problem: 'record ${type.format(recordType)} truncated at $position');
      }
      values.putIfAbsent(recordType, () => bytes.sublist(start, start + size));
      position = start + size;
    }
    return (values: values, problem: null);
  }

  String get summary => 'records from $offset · ${length.label} · type ${type.label}';
}

/// One value of a manufacturer or service data payload, shown as `raw × scale + add`.
class const AdvertisementField(
  final String name,

  /// From the payload start, or from the start of the [record] value with [RecordFormat].
  final int offset,
  final AdvertisementFieldType type, {
  final int length = 1,
  final double scale = 1,
  final double add = 0,
  final String unit = '',

  /// The record type that holds this value; only used with [RecordFormat].
  final int? record,

  /// The lowest bit of a bit range, counted from the least significant bit of an unsigned [type].
  final int bit = 0,

  /// Bits in the range, or null for the whole value.
  final int? bits,
}) {
  /// Throws a [FormatException] for stored data that no longer describes a field.
  factory fromJson(Map<String, dynamic> json) {
    final AdvertisementField field;
    try {
      field = AdvertisementField(
        json['name'] as String,
        json['offset'] as int,
        AdvertisementFieldType.values.byName(json['type'] as String),
        length: json['length'] as int,
        scale: (json['scale'] as num).toDouble(),
        add: (json['add'] as num).toDouble(),
        unit: json['unit'] as String,
        record: json['record'] as int?,
        bit: json['bit'] as int,
        bits: json['bits'] as int?,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(FormatException('Invalid parser field: $error'), stackTrace);
    }
    if (field.scale == 0 || !field.scale.isFinite) {
      throw FormatException('Invalid parser field ${field.name}: scale ${field.scale}');
    }
    if (!field.add.isFinite) {
      throw FormatException('Invalid parser field ${field.name}: add ${field.add}');
    }
    if (field.offset < 0 || field.length < 1 || field.bit < 0) {
      throw FormatException(
        'Invalid parser field ${field.name}: offset ${field.offset}, length ${field.length}, bit ${field.bit}',
      );
    }
    final bits = field.bits;
    if (bits != null && (!field.type.unsigned || bits < 1 || field.bit + bits > field.size * 8)) {
      throw FormatException(
        'Invalid parser field ${field.name}: $bits bits from bit ${field.bit} of ${field.type.label}',
      );
    }
    return field;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'offset': offset,
    'type': type.name,
    'length': length,
    'scale': scale,
    'add': add,
    'unit': unit,
    'record': record,
    'bit': bit,
    'bits': bits,
  };

  int get size => type.size ?? length;

  /// Type and position, for parser lists.
  String summary(RecordFormat? records) => [
    '$name: ${type.label}',
    if (records != null && record != null) 'record ${records.type.format(record!)}',
    if (bits == 1) 'bit $bit' else if (bits != null) 'bits $bit–${bit + bits! - 1}',
  ].join(' · ');

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
    final num raw = switch (type) {
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
    final num value;
    final bits = this.bits;
    if (bits != null) {
      if (!type.unsigned) {
        return 'bits need an unsigned type';
      }
      if (bit < 0 || bits < 1 || bit + bits > size * 8) {
        return 'bits beyond ${size * 8}-bit value';
      }
      value = raw.toInt() >> bit & (1 << bits) - 1;
    } else {
      value = raw;
    }
    final scaled = value * scale + add;
    final integerType = type != AdvertisementFieldType.float32le && type != AdvertisementFieldType.float32be;
    final text = integerType && scaled.isFinite && scale == scale.roundToDouble() && add == add.roundToDouble()
        ? '${scaled.round()}'
        : scaled.toStringAsFixed(_decimals);
    return unit.isEmpty ? text : '$text $unit';
  }

  /// Enough decimals to show one step of the scale: 0.1 → 1, 0.005 and 1/256 → 3.
  /// Unscaled floats keep two.
  int get _decimals {
    // A zero or non-finite scale has no step to show; validation rejects it, but a preview may still see it.
    if (scale == 1 || scale == 0 || !scale.isFinite) {
      return 2;
    }
    // The epsilon absorbs rounding, e.g. -log10(0.001) = 2.9999999999999996.
    return (-log(scale.abs()) / ln10 - 1e-9).ceil().clamp(1, 6);
  }
}

/// Human-readable advertisement fields; without parsers also the identity used to detect payload changes.
/// Parsed values follow the payload they were read from.
List<String> describeAdvertisement(AdvertisementData data, {List<AdvertisementParser> parsers = const []}) => [
  'Name: ${data.advName}',
  if (data.txPowerLevel != null) 'TX power: ${data.txPowerLevel} dBm',
  if (data.appearance != null) 'Appearance: 0x${data.appearance!.toRadixString(16)}',
  for (final uuid in data.serviceUuids) 'Service: $uuid',
  for (final entry in data.manufacturerData.entries) ...[
    'Manufacturer 0x${entry.key.toRadixString(16)}: ${PayloadCodec.hex(entry.value)}',
    for (final parser in parsers)
      for (final line in parser.read(companyId: entry.key, bytes: entry.value)) '  ↳ $line',
  ],
  for (final entry in data.serviceData.entries) ...[
    'Service data ${entry.key}: ${PayloadCodec.hex(entry.value)}',
    for (final parser in parsers)
      for (final line in parser.read(serviceUuid: entry.key, bytes: entry.value)) '  ↳ $line',
  ],
];

/// Only the values the parsers read, for compact history rows.
List<String> parsedValues(AdvertisementData data, List<AdvertisementParser> parsers) => [
  for (final parser in parsers) ...[
    for (final entry in data.manufacturerData.entries) ...parser.read(companyId: entry.key, bytes: entry.value),
    for (final entry in data.serviceData.entries) ...parser.read(serviceUuid: entry.key, bytes: entry.value),
  ],
];
