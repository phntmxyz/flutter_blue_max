import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';

const _apple = 0x004c;

/// Widely used formats; the first launch starts with these.
final commonParsers = [
  // Bluetooth SIG Battery Service; few devices advertise it, but it is the standard place to do so.
  AdvertisementParser(
    name: 'Battery',
    source: AdvertisementSource.service,
    serviceUuid: Guid('180f'),
    fields: const [AdvertisementField('Level', 0, AdvertisementFieldType.uint8, unit: '%')],
  ),
  // Eddystone TLM: beacon telemetry; the temperature is 8.8 fixed point.
  AdvertisementParser(
    name: 'Eddystone TLM',
    source: AdvertisementSource.service,
    serviceUuid: Guid('feaa'),
    match: const [0x20, 0x00],
    fields: const [
      AdvertisementField('Battery', 2, AdvertisementFieldType.uint16be, unit: 'mV'),
      AdvertisementField('Temperature', 4, AdvertisementFieldType.int16be, scale: 1 / 256, unit: '°C'),
      AdvertisementField('Advertisements', 6, AdvertisementFieldType.uint32be),
      AdvertisementField('Uptime', 10, AdvertisementFieldType.uint32be, scale: 0.1, unit: 's'),
    ],
  ),
  // Apple platforms hide iBeacon frames from apps; Android and Linux report them.
  const AdvertisementParser(
    name: 'iBeacon',
    source: AdvertisementSource.manufacturer,
    companyId: _apple,
    match: [0x02, 0x15],
    fields: [
      AdvertisementField('UUID', 2, AdvertisementFieldType.hex, length: 16),
      AdvertisementField('Major', 18, AdvertisementFieldType.uint16be),
      AdvertisementField('Minor', 20, AdvertisementFieldType.uint16be),
      AdvertisementField('Measured power', 22, AdvertisementFieldType.int8, unit: 'dBm'),
    ],
  ),
  // Every iPhone, Mac and AirPods case advertises Continuity messages, e.g. 10 for Nearby Info.
  const AdvertisementParser(
    name: 'Apple Continuity',
    source: AdvertisementSource.manufacturer,
    companyId: _apple,
    fields: [AdvertisementField('Message type', 0, AdvertisementFieldType.hex)],
  ),
];
