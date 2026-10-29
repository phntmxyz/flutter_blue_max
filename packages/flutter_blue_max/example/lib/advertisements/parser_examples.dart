import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';

/// Reserved by the Bluetooth SIG for testing; the FBM test dongle uses it for every frame.
const _testCompany = 0xffff;

/// Frames of the FBM test dongle firmware; the first launch starts with these.
const testDongleParsers = [
  // FBM-Echo-XXXX and FBM-Ext-XXXX advertise the dongle's state.
  AdvertisementParser(
    name: 'FBM status',
    source: AdvertisementSource.manufacturer,
    companyId: _testCompany,
    match: [0x01],
    fields: [
      AdvertisementField('Mode', 1, AdvertisementFieldType.uint8),
      AdvertisementField('Platform', 2, AdvertisementFieldType.uint8),
      AdvertisementField('Flags', 3, AdvertisementFieldType.hex),
      AdvertisementField('Counter', 4, AdvertisementFieldType.uint16le),
      AdvertisementField('Button', 6, AdvertisementFieldType.uint8),
    ],
  ),
  // FBM-Data-XXXX advertises synthetic sensor values derived from a counter, one per field type.
  AdvertisementParser(
    name: 'FBM sensor',
    source: AdvertisementSource.manufacturer,
    companyId: _testCompany,
    match: [0x02],
    fields: [
      AdvertisementField('Counter', 1, AdvertisementFieldType.uint32le),
      AdvertisementField('Temperature', 5, AdvertisementFieldType.int16le, scale: 0.01, unit: '°C'),
      AdvertisementField('Humidity', 7, AdvertisementFieldType.uint8, unit: '%'),
      AdvertisementField('Battery', 8, AdvertisementFieldType.uint16be, unit: 'mV'),
      AdvertisementField('Pressure', 10, AdvertisementFieldType.float32le, unit: 'hPa'),
      AdvertisementField('Delta', 14, AdvertisementFieldType.int8),
      AdvertisementField('Uptime', 15, AdvertisementFieldType.uint24le, unit: 's'),
      AdvertisementField('Tag', 18, AdvertisementFieldType.ascii, length: 6),
    ],
  ),
];
