import "dart:typed_data";

import "package:flutter_blue_max_platform_interface/src/device_identifier.dart";
import "package:flutter_blue_max_platform_interface/src/guid.dart";
import "package:flutter_blue_max_platform_interface/src/log_level.dart";

/// Request for the current state of the Bluetooth adapter.
class BmBluetoothAdapterStateRequest {
  /// Creates a [BmBluetoothAdapterStateRequest].
  BmBluetoothAdapterStateRequest();
}

/// State of the Bluetooth adapter. The enum index is the value used on the platform channel.
enum BmAdapterStateEnum {
  /// The state is not known yet.
  unknown, // 0
  /// Bluetooth is not available on this device.
  unavailable, // 1
  /// The app is not authorized to use Bluetooth.
  unauthorized, // 2
  /// The adapter is turning on.
  turningOn, // 3
  /// The adapter is on.
  on, // 4
  /// The adapter is turning off.
  turningOff, // 5
  /// The adapter is off.
  off, // 6
}

/// State of the Bluetooth adapter.
class BmBluetoothAdapterState {
  /// Creates a [BmBluetoothAdapterState].
  BmBluetoothAdapterState({required this.adapterState});

  factory BmBluetoothAdapterState.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json["adapter_state"] as int],
    );
  }

  /// The state of the adapter.
  BmAdapterStateEnum adapterState;
}

/// Request for the name of the Bluetooth adapter.
class BmBluetoothAdapterNameRequest {
  /// Creates a [BmBluetoothAdapterNameRequest].
  BmBluetoothAdapterNameRequest();
}

/// Name of the Bluetooth adapter.
class BmBluetoothAdapterName {
  /// Creates a [BmBluetoothAdapterName].
  BmBluetoothAdapterName({required this.adapterName});

  /// The name of the adapter.
  String adapterName;
}

/// Scan filter on manufacturer specific data.
class BmMsdFilter {
  /// Creates a [BmMsdFilter].
  BmMsdFilter(this.manufacturerId, this.data, this.mask);

  /// Company identifier of the manufacturer.
  int manufacturerId;

  /// Data to match against.
  List<int>? data;

  /// Mask applied to the data before matching.
  List<int>? mask;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map["manufacturer_id"] = manufacturerId;
    map["data"] = Uint8List.fromList(data ?? []);
    map["mask"] = Uint8List.fromList(mask ?? []);
    return map;
  }
}

/// Scan filter on service data.
class BmServiceDataFilter {
  /// Creates a [BmServiceDataFilter].
  BmServiceDataFilter(this.service, this.data, this.mask);

  /// UUID of the service the data belongs to.
  Guid service;

  /// Data to match against.
  List<int> data;

  /// Mask applied to the data before matching.
  List<int> mask;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map["service"] = service.str;
    map["data"] = Uint8List.fromList(data);
    map["mask"] = Uint8List.fromList(mask);
    return map;
  }
}

/// Settings for starting a scan.
class BmScanSettings {
  /// Creates a [BmScanSettings].
  BmScanSettings({
    required this.withServices,
    required this.withRemoteIds,
    required this.withNames,
    required this.withKeywords,
    required this.withMsd,
    required this.withServiceData,
    required this.continuousUpdates,
    required this.continuousDivisor,
    required this.androidLegacy,
    required this.androidScanMode,
    required this.androidUsesFineLocation,
    this.androidCheckLocationServices = true,
    required this.webOptionalServices,
  });

  /// Only match devices advertising one of these service UUIDs.
  final List<Guid> withServices;

  /// Only match devices with one of these remote ids.
  final List<String> withRemoteIds;

  /// Only match devices whose advertised name equals one of these names.
  final List<String> withNames;

  /// Only match devices whose advertised name contains one of these keywords as a substring.
  final List<String> withKeywords;

  /// Only match devices advertising matching manufacturer data.
  final List<BmMsdFilter> withMsd;

  /// Only match devices advertising matching service data.
  final List<BmServiceDataFilter> withServiceData;

  /// Whether to report every advertisement of a device instead of only the first.
  final bool continuousUpdates;

  /// Only every n-th advertisement is reported when [continuousUpdates] is set.
  final int continuousDivisor;

  /// Whether to scan on the 1M PHY only (Android).
  final bool androidLegacy;

  /// The Android scan mode to use.
  final int androidScanMode;

  /// Whether to request the fine location permission for scanning (Android).
  final bool androidUsesFineLocation;

  /// Whether to check that location services are enabled before scanning (Android).
  final bool androidCheckLocationServices;

  /// Services the page may access after pairing, even if not scanned for (web).
  final List<Guid> webOptionalServices;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["with_services"] = withServices.map((s) => s.str).toList();
    data["with_remote_ids"] = withRemoteIds;
    data["with_names"] = withNames;
    data["with_keywords"] = withKeywords;
    data["with_msd"] = withMsd.map((d) => d.toMap()).toList();
    data["with_service_data"] = withServiceData.map((d) => d.toMap()).toList();
    data["continuous_updates"] = continuousUpdates;
    data["continuous_divisor"] = continuousDivisor;
    data["android_legacy"] = androidLegacy;
    data["android_scan_mode"] = androidScanMode;
    data["android_uses_fine_location"] = androidUsesFineLocation;
    data["android_check_location_services"] = androidCheckLocationServices;
    data["web_optional_services"] = webOptionalServices.map((s) => s.str).toList();
    return data;
  }
}

/// Request to stop a running scan.
class BmStopScanRequest {
  /// Creates a [BmStopScanRequest].
  BmStopScanRequest();
}

/// A single advertisement received while scanning.
class BmScanAdvertisement {
  /// Creates a [BmScanAdvertisement].
  BmScanAdvertisement({
    required this.remoteId,
    required this.platformName,
    required this.advName,
    required this.connectable,
    required this.txPowerLevel,
    required this.appearance,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
    required this.rssi,
  });

  factory BmScanAdvertisement.fromMap(Map<dynamic, dynamic> json) {
    // Get raw data
    final rawManufacturerData = (json["manufacturer_data"] ?? <dynamic, dynamic>{}) as Map<dynamic, dynamic>;
    final rawServiceData = (json["service_data"] ?? <dynamic, dynamic>{}) as Map<dynamic, dynamic>;
    final rawServiceUuids = (json["service_uuids"] ?? <dynamic>[]) as List<dynamic>;

    // Cast the data to the right type
    final Map<int, List<int>> manufacturerData = {};
    for (final entry in rawManufacturerData.entries) {
      manufacturerData[entry.key as int] = entry.value as List<int>;
    }
    // Cast the data to the right type
    final Map<Guid, List<int>> serviceData = {};
    for (final entry in rawServiceData.entries) {
      serviceData[Guid(entry.key as String)] = entry.value as List<int>;
    }
    // Cast the data to the right type
    final List<Guid> serviceUuids = [];
    for (final uuid in rawServiceUuids) {
      serviceUuids.add(Guid(uuid as String));
    }

    return BmScanAdvertisement(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      platformName: json["platform_name"] as String?,
      advName: json["adv_name"] as String?,
      connectable: json["connectable"] != null && json["connectable"] != 0,
      txPowerLevel: json["tx_power_level"] as int?,
      appearance: json["appearance"] as int?,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      serviceUuids: serviceUuids,
      rssi: json["rssi"] as int? ?? 0,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The name of the device as reported by the platform.
  final String? platformName;

  /// The name of the device from its advertisement.
  final String? advName;

  /// Whether the device can be connected to.
  final bool connectable;

  /// The transmit power level from the advertisement, if present.
  final int? txPowerLevel;

  /// The appearance from the advertisement, if present.
  final int? appearance; // not supported on iOS / macOS
  /// Manufacturer specific data by manufacturer id.
  final Map<int, List<int>> manufacturerData;

  /// Service data by service UUID.
  final Map<Guid, List<int>> serviceData;

  /// UUIDs of the services in the advertisement.
  final List<Guid> serviceUuids;

  /// Received signal strength in dBm, 0 if the platform reported none.
  final int rssi;
}

/// Result of a scan, carrying a batch of advertisements or an error.
class BmScanResponse {
  /// Creates a [BmScanResponse].
  BmScanResponse({
    required this.advertisements,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmScanResponse.fromMap(Map<dynamic, dynamic> json) {
    final List<BmScanAdvertisement> advertisements = [];
    for (final item in json["advertisements"] as List<dynamic>) {
      advertisements.add(BmScanAdvertisement.fromMap(item as Map<dynamic, dynamic>));
    }

    final bool success = json["success"] == null || json["success"] != 0;

    return BmScanResponse(
      advertisements: advertisements,
      success: success,
      errorCode: !success ? json["error_code"] as int : 0,
      errorString: !success ? json["error_string"] as String : "",
    );
  }

  /// The received advertisements.
  final List<BmScanAdvertisement> advertisements;

  /// Whether the operation succeeded.
  final bool success;

  /// Platform specific error code, 0 if there is no error.
  final int errorCode;

  /// Platform specific error description.
  final String errorString;
}

/// Request to connect to a device.
class BmConnectRequest {
  /// Creates a [BmConnectRequest].
  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  /// Identifier of the device to connect to.
  DeviceIdentifier remoteId;

  /// Whether to connect as soon as the device becomes available instead of connecting directly.
  bool autoConnect;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["auto_connect"] = autoConnect ? 1 : 0;
    return data;
  }
}

/// Request to disconnect from a device.
class BmDisconnectRequest {
  /// Creates a [BmDisconnectRequest].
  BmDisconnectRequest({
    required this.remoteId,
  });

  /// Identifier of the device to disconnect from.
  DeviceIdentifier remoteId;
}

/// A Bluetooth device as reported by the platform.
class BmBluetoothDevice {
  /// Creates a [BmBluetoothDevice].
  BmBluetoothDevice({
    required this.remoteId,
    required this.platformName,
  });

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDevice(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      platformName: json["platform_name"] as String?,
    );
  }

  /// Identifier of the remote device.
  DeviceIdentifier remoteId;

  /// The name of the device as reported by the platform.
  String? platformName;
}

/// Event emitted when the name of a remote device changed.
class BmNameChanged {
  /// Creates a [BmNameChanged].
  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  factory BmNameChanged.fromMap(Map<dynamic, dynamic> json) {
    return BmNameChanged(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      name: json["name"] as String,
    );
  }

  /// Identifier of the remote device.
  DeviceIdentifier remoteId;

  /// The new name of the device.
  String name;
}

/// A GATT service of a remote device.
class BmBluetoothService {
  /// Creates a [BmBluetoothService].
  BmBluetoothService({
    required this.serviceUuid,
    required this.remoteId,
    required this.characteristics,
    required this.primaryServiceUuid,
  });

  factory BmBluetoothService.fromMap(Map<dynamic, dynamic> json) {
    // convert characteristics
    final List<BmBluetoothCharacteristic> chrs = [];
    for (final v in json["characteristics"] as List<dynamic>) {
      chrs.add(BmBluetoothCharacteristic.fromMap(v as Map<dynamic, dynamic>));
    }

    return BmBluetoothService(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      serviceUuid: Guid(json["service_uuid"] as String),
      primaryServiceUuid: Guid.parse(json["primary_service_uuid"] as String?),
      characteristics: chrs,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// The characteristics of the service.
  List<BmBluetoothCharacteristic> characteristics;
}

/// A GATT characteristic of a remote device.
class BmBluetoothCharacteristic {
  /// Creates a [BmBluetoothCharacteristic].
  BmBluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    this.instanceId,
    required this.descriptors,
    required this.properties,
  });

  factory BmBluetoothCharacteristic.fromMap(Map<dynamic, dynamic> json) {
    // convert descriptors
    final List<BmBluetoothDescriptor> descs = [];
    for (final v in json["descriptors"] as List<dynamic>) {
      descs.add(BmBluetoothDescriptor.fromMap(v as Map<dynamic, dynamic>));
    }

    return BmBluetoothCharacteristic(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      serviceUuid: Guid(json["service_uuid"] as String),
      characteristicUuid: Guid(json["characteristic_uuid"] as String),
      primaryServiceUuid: Guid.parse(json["primary_service_uuid"] as String?),
      instanceId: json["instance_id"] as int?,
      descriptors: descs,
      properties: BmCharacteristicProperties.fromMap(json["properties"] as Map<dynamic, dynamic>),
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// The descriptors of the characteristic.
  List<BmBluetoothDescriptor> descriptors;

  /// The properties of the characteristic.
  BmCharacteristicProperties properties;
}

/// A GATT descriptor of a remote device.
class BmBluetoothDescriptor {
  /// Creates a [BmBluetoothDescriptor].
  BmBluetoothDescriptor({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
    this.instanceId,
  });

  factory BmBluetoothDescriptor.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDescriptor(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      serviceUuid: Guid(json["service_uuid"] as String),
      characteristicUuid: Guid(json["characteristic_uuid"] as String),
      descriptorUuid: Guid(json["descriptor_uuid"] as String),
      primaryServiceUuid: Guid.parse(json["primary_service_uuid"] as String?),
      instanceId: json["instance_id"] as int?,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the descriptor.
  final Guid descriptorUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;
}

/// Properties of a GATT characteristic, i.e. which operations it supports.
class BmCharacteristicProperties {
  /// Creates a [BmCharacteristicProperties].
  BmCharacteristicProperties({
    required this.broadcast,
    required this.read,
    required this.writeWithoutResponse,
    required this.write,
    required this.notify,
    required this.indicate,
    required this.authenticatedSignedWrites,
    required this.extendedProperties,
    required this.notifyEncryptionRequired,
    required this.indicateEncryptionRequired,
  });

  factory BmCharacteristicProperties.fromMap(Map<dynamic, dynamic> json) {
    return BmCharacteristicProperties(
      broadcast: json["broadcast"] != 0,
      read: json["read"] != 0,
      writeWithoutResponse: json["write_without_response"] != 0,
      write: json["write"] != 0,
      notify: json["notify"] != 0,
      indicate: json["indicate"] != 0,
      authenticatedSignedWrites: json["authenticated_signed_writes"] != 0,
      extendedProperties: json["extended_properties"] != 0,
      notifyEncryptionRequired: json["notify_encryption_required"] != 0,
      indicateEncryptionRequired: json["indicate_encryption_required"] != 0,
    );
  }

  /// The characteristic can be broadcast.
  bool broadcast;

  /// The characteristic can be read.
  bool read;

  /// The characteristic can be written without response.
  bool writeWithoutResponse;

  /// The characteristic can be written with response.
  bool write;

  /// The characteristic supports notifications.
  bool notify;

  /// The characteristic supports indications.
  bool indicate;

  /// The characteristic supports authenticated signed writes.
  bool authenticatedSignedWrites;

  /// The characteristic has extended properties.
  bool extendedProperties;

  /// Notifications require an encrypted connection.
  bool notifyEncryptionRequired;

  /// Indications require an encrypted connection.
  bool indicateEncryptionRequired;
}

/// Request to discover the GATT services of a device.
class BmDiscoverServicesRequest {
  /// Creates a [BmDiscoverServicesRequest].
  BmDiscoverServicesRequest({
    required this.remoteId,
  });

  /// Identifier of the device to discover the services of.
  DeviceIdentifier remoteId;
}

/// Result of a service discovery.
class BmDiscoverServicesResult {
  /// Creates a [BmDiscoverServicesResult].
  BmDiscoverServicesResult({
    required this.remoteId,
    required this.services,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDiscoverServicesResult.fromMap(Map<dynamic, dynamic> json) {
    return BmDiscoverServicesResult(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      services: (json["services"] as List<dynamic>)
          .map((e) => BmBluetoothService.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      success: json["success"] != 0,
      errorCode: json["error_code"] as int,
      errorString: json["error_string"] as String,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The discovered services.
  final List<BmBluetoothService> services;

  /// Whether the operation succeeded.
  final bool success;

  /// Platform specific error code, 0 if there is no error.
  final int errorCode;

  /// Platform specific error description.
  final String errorString;
}

/// Request to read a characteristic.
class BmReadCharacteristicRequest {
  /// Creates a [BmReadCharacteristicRequest].
  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    this.primaryServiceUuid,
    this.instanceId,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["service_uuid"] = serviceUuid.str;
    data["characteristic_uuid"] = characteristicUuid.str;
    data["primary_service_uuid"] = primaryServiceUuid?.str;
    data["instance_id"] = instanceId;
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

/// Value of a characteristic, delivered after a read, a write or a notification.
class BmCharacteristicData {
  /// Creates a [BmCharacteristicData].
  BmCharacteristicData({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
    this.instanceId,
  });

  factory BmCharacteristicData.fromMap(Map<dynamic, dynamic> json) {
    return BmCharacteristicData(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      serviceUuid: Guid(json["service_uuid"] as String),
      characteristicUuid: Guid(json["characteristic_uuid"] as String),
      primaryServiceUuid: Guid.parse(json["primary_service_uuid"] as String?),
      instanceId: json["instance_id"] as int?,
      value: json["value"] as Uint8List?,
      success: json["success"] != 0,
      errorCode: json["error_code"] as int,
      errorString: json["error_string"] as String,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// null when the platform reports no value, iOS & macOS do so for a failed read
  final List<int>? value;

  /// Whether the operation succeeded.
  final bool success;

  /// Platform specific error code, 0 if there is no error.
  final int errorCode;

  /// Platform specific error description.
  final String errorString;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;
}

/// Request to read a descriptor.
class BmReadDescriptorRequest {
  /// Creates a [BmReadDescriptorRequest].
  BmReadDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
    this.instanceId,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the descriptor.
  final Guid descriptorUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["service_uuid"] = serviceUuid.str;
    data["characteristic_uuid"] = characteristicUuid.str;
    data["descriptor_uuid"] = descriptorUuid.str;
    data["primary_service_uuid"] = primaryServiceUuid?.str;
    data["instance_id"] = instanceId;
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

/// How a characteristic is written.
enum BmWriteType {
  /// Write and wait for a response from the device.
  withResponse,

  /// Write without waiting for a response.
  withoutResponse,
}

/// Request to write a characteristic.
class BmWriteCharacteristicRequest {
  /// Creates a [BmWriteCharacteristicRequest].
  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    this.instanceId,
    required this.writeType,
    required this.allowLongWrite,
    required this.value,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// Whether to write with or without response.
  final BmWriteType writeType;

  /// Whether a value larger than the MTU may be written.
  final bool allowLongWrite;

  /// The bytes to write.
  final List<int> value;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["service_uuid"] = serviceUuid.str;
    data["characteristic_uuid"] = characteristicUuid.str;
    data["primary_service_uuid"] = primaryServiceUuid?.str;
    data["instance_id"] = instanceId;
    data["write_type"] = writeType.index;
    data["allow_long_write"] = allowLongWrite ? 1 : 0;
    data["value"] = Uint8List.fromList(value);
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

/// Request to write a descriptor.
class BmWriteDescriptorRequest {
  /// Creates a [BmWriteDescriptorRequest].
  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.descriptorUuid,
    this.instanceId,
    required this.value,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// UUID of the descriptor.
  final Guid descriptorUuid;

  /// The bytes to write.
  final List<int> value;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["service_uuid"] = serviceUuid.str;
    data["characteristic_uuid"] = characteristicUuid.str;
    data["descriptor_uuid"] = descriptorUuid.str;
    data["primary_service_uuid"] = primaryServiceUuid?.str;
    data["instance_id"] = instanceId;
    data["value"] = Uint8List.fromList(value);
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

/// Value of a descriptor, delivered after a read or a write.
class BmDescriptorData {
  /// Creates a [BmDescriptorData].
  BmDescriptorData({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
    this.instanceId,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDescriptorData.fromMap(Map<dynamic, dynamic> json) {
    return BmDescriptorData(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      serviceUuid: Guid(json["service_uuid"] as String),
      characteristicUuid: Guid(json["characteristic_uuid"] as String),
      descriptorUuid: Guid(json["descriptor_uuid"] as String),
      primaryServiceUuid: Guid.parse(json["primary_service_uuid"] as String?),
      instanceId: json["instance_id"] as int?,
      value: json["value"] as Uint8List,
      success: json["success"] != 0,
      errorCode: json["error_code"] as int,
      errorString: json["error_string"] as String,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the descriptor.
  final Guid descriptorUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// The value as bytes.
  final List<int> value;

  /// Whether the operation succeeded.
  final bool success;

  /// Platform specific error code, 0 if there is no error.
  final int errorCode;

  /// Platform specific error description.
  final String errorString;
}

/// Request to enable or disable notifications or indications of a characteristic.
class BmSetNotifyValueRequest {
  /// Creates a [BmSetNotifyValueRequest].
  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    this.instanceId,
    required this.forceIndications,
    required this.enable,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// UUID of the service.
  final Guid serviceUuid;

  /// UUID of the characteristic.
  final Guid characteristicUuid;

  /// UUID of the primary service, set when [serviceUuid] is an included service.
  final Guid? primaryServiceUuid;

  /// Instance id to tell apart attributes with the same UUID, if the platform provides one.
  final int? instanceId;

  /// Whether to use indications even if the characteristic supports notifications.
  final bool forceIndications;

  /// Whether to enable or disable notifications or indications.
  final bool enable;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["service_uuid"] = serviceUuid.str;
    data["characteristic_uuid"] = characteristicUuid.str;
    data["primary_service_uuid"] = primaryServiceUuid?.str;
    data["instance_id"] = instanceId;
    data["force_indications"] = forceIndications;
    data["enable"] = enable;
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

/// Connection state of a device. The enum index is the value used on the platform channel.
enum BmConnectionStateEnum {
  /// The device is disconnected.
  disconnected, // 0
  /// The device is connected.
  connected, // 1
}

/// Event emitted when the connection state of a device changed.
class BmConnectionStateResponse {
  /// Creates a [BmConnectionStateResponse].
  BmConnectionStateResponse({
    required this.remoteId,
    required this.connectionState,
    required this.disconnectReasonCode,
    required this.disconnectReasonString,
  });

  factory BmConnectionStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmConnectionStateResponse(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      connectionState: BmConnectionStateEnum.values[json["connection_state"] as int],
      disconnectReasonCode: json["disconnect_reason_code"] as int?,
      disconnectReasonString: json["disconnect_reason_string"] as String?,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The new connection state.
  final BmConnectionStateEnum connectionState;

  /// Platform specific reason code of the disconnect, if any.
  final int? disconnectReasonCode;

  /// Platform specific reason of the disconnect, if any.
  final String? disconnectReasonString;
}

/// Request for the bonded devices.
class BmBondedDevicesRequest {
  /// Creates a [BmBondedDevicesRequest].
  BmBondedDevicesRequest();
}

/// Request for the devices already connected to the system.
class BmSystemDevicesRequest {
  /// Creates a [BmSystemDevicesRequest].
  BmSystemDevicesRequest({
    required this.withServices,
  });

  /// Only return devices that offer one of these services.
  final List<Guid> withServices;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["with_services"] = withServices.map((s) => s.str).toList();
    return data;
  }
}

/// A list of devices.
class BmDevicesList {
  /// Creates a [BmDevicesList].
  BmDevicesList({required this.devices});

  factory BmDevicesList.fromMap(Map<dynamic, dynamic> json) {
    // convert to BmBluetoothDevice
    final List<BmBluetoothDevice> devices = [];
    for (final device in json["devices"] as List<dynamic>) {
      devices.add(BmBluetoothDevice.fromMap(device as Map<dynamic, dynamic>));
    }
    return BmDevicesList(devices: devices);
  }

  /// The devices.
  final List<BmBluetoothDevice> devices;
}

/// Request to change the MTU of a connection.
class BmMtuChangeRequest {
  /// Creates a [BmMtuChangeRequest].
  BmMtuChangeRequest({required this.remoteId, required this.mtu});

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The requested MTU in bytes.
  final int mtu;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["mtu"] = mtu;
    return data;
  }
}

/// Event emitted when the MTU of a connection changed, or the request to change it failed.
class BmMtuChangedResponse {
  /// Creates a [BmMtuChangedResponse].
  BmMtuChangedResponse({
    required this.remoteId,
    required this.mtu,
    this.success = true,
    this.errorCode = 0,
    this.errorString = "",
  });

  factory BmMtuChangedResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmMtuChangedResponse(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      mtu: json["mtu"] as int,
      success: json["success"] != 0,
      errorCode: json["error_code"] as int,
      errorString: json["error_string"] as String,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The MTU in bytes after the change.
  final int mtu;

  /// Whether the operation succeeded.
  final bool success;

  /// Platform specific error code, 0 if there is no error.
  final int errorCode;

  /// Platform specific error description.
  final String errorString;
}

/// Request to read the RSSI of a connected device.
class BmReadRssiRequest {
  /// Creates a [BmReadRssiRequest].
  BmReadRssiRequest({
    required this.remoteId,
  });

  /// Identifier of the device to read the RSSI of.
  DeviceIdentifier remoteId;
}

/// Result of an RSSI read.
class BmReadRssiResult {
  /// Creates a [BmReadRssiResult].
  BmReadRssiResult({
    required this.remoteId,
    required this.rssi,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmReadRssiResult.fromMap(Map<dynamic, dynamic> json) {
    return BmReadRssiResult(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      rssi: json["rssi"] as int,
      success: json["success"] != 0,
      errorCode: json["error_code"] as int,
      errorString: json["error_string"] as String,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// Received signal strength in dBm.
  final int rssi;

  /// Whether the operation succeeded.
  final bool success;

  /// Platform specific error code, 0 if there is no error.
  final int errorCode;

  /// Platform specific error description.
  final String errorString;
}

/// Connection priority of a connection. The enum index is the value used on the platform channel.
enum BmConnectionPriorityEnum {
  /// Balanced power consumption and latency.
  balanced, // 0
  /// Low latency at the cost of higher power consumption.
  high, // 1
  /// Low power consumption at the cost of latency.
  lowPower, // 2
}

/// Request to change the connection priority.
class BmConnectionPriorityRequest {
  /// Creates a [BmConnectionPriorityRequest].
  BmConnectionPriorityRequest({
    required this.remoteId,
    required this.connectionPriority,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The requested connection priority.
  final BmConnectionPriorityEnum connectionPriority;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["connection_priority"] = connectionPriority.index;
    return data;
  }
}

/// Request to set the preferred PHY of a connection.
class BmPreferredPhy {
  /// Creates a [BmPreferredPhy].
  BmPreferredPhy({
    required this.remoteId,
    required this.txPhy,
    required this.rxPhy,
    required this.phyOptions,
  });

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// Bitwise OR of the allowed PHYs for transmitting.
  final int txPhy;

  /// Bitwise OR of the allowed PHYs for receiving.
  final int rxPhy;

  /// Preferred coding when transmitting on the coded PHY, as the index of the coding option.
  final int phyOptions;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["tx_phy"] = txPhy;
    data["rx_phy"] = rxPhy;
    data["phy_options"] = phyOptions;
    return data;
  }
}

/// Request for the bond state of a device.
class BmBondStateRequest {
  /// Creates a [BmBondStateRequest].
  BmBondStateRequest({
    required this.remoteId,
  });

  /// Identifier of the remote device.
  DeviceIdentifier remoteId;
}

/// Bond state of a device. The enum index is the value used on the platform channel.
enum BmBondStateEnum {
  /// The device is not bonded.
  none, // 0
  /// Bonding is in progress.
  bonding, // 1
  /// The device is bonded.
  bonded, // 2
}

/// Bond state of a device, also emitted when it changed.
class BmBondStateResponse {
  /// Creates a [BmBondStateResponse].
  BmBondStateResponse({
    required this.remoteId,
    required this.bondState,
    required this.prevState,
  });

  factory BmBondStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmBondStateResponse(
      remoteId: DeviceIdentifier(json["remote_id"] as String),
      bondState: BmBondStateEnum.values[json["bond_state"] as int],
      prevState: json["prev_state"] != null ? BmBondStateEnum.values[json["prev_state"] as int] : null,
    );
  }

  /// Identifier of the remote device.
  final DeviceIdentifier remoteId;

  /// The current bond state.
  final BmBondStateEnum bondState;

  /// The previous bond state, if known.
  final BmBondStateEnum? prevState;
}

/// Request to bond with a device.
class BmCreateBondRequest {
  /// Creates a [BmCreateBondRequest].
  BmCreateBondRequest({
    required this.remoteId,
    required this.pin,
  });

  /// Identifier of the device to bond with.
  DeviceIdentifier remoteId;

  /// The PIN to bond with, if any.
  Uint8List? pin;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["pin"] = pin;
    return data;
  }
}

/// Request to remove the bond with a device.
class BmRemoveBondRequest {
  /// Creates a [BmRemoveBondRequest].
  BmRemoveBondRequest({
    required this.remoteId,
  });

  /// Identifier of the device to remove the bond with.
  DeviceIdentifier remoteId;
}

/// Request to clear the GATT cache of a device.
class BmClearGattCacheRequest {
  /// Creates a [BmClearGattCacheRequest].
  BmClearGattCacheRequest({
    required this.remoteId,
  });

  /// Identifier of the device to clear the GATT cache of.
  DeviceIdentifier remoteId;
}

/// Event emitted when the plugin is detached from the Flutter engine.
class BmDetachedFromEngineResponse {
  /// Creates a [BmDetachedFromEngineResponse].
  BmDetachedFromEngineResponse();
}

/// Request to turn the Bluetooth adapter off.
class BmTurnOffRequest {
  /// Creates a [BmTurnOffRequest].
  BmTurnOffRequest();
}

/// Request to turn the Bluetooth adapter on.
class BmTurnOnRequest {
  /// Creates a [BmTurnOnRequest].
  BmTurnOnRequest();
}

/// Response to a request to turn the Bluetooth adapter on.
class BmTurnOnResponse {
  /// Creates a [BmTurnOnResponse].
  BmTurnOnResponse({
    required this.userAccepted,
  });

  factory BmTurnOnResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmTurnOnResponse(
      userAccepted: json["user_accepted"] as bool,
    );
  }

  /// Whether the user accepted turning Bluetooth on.
  bool userAccepted;
}

/// Request to set the log level of the platform layer.
class BmSetLogLevelRequest {
  /// Creates a [BmSetLogLevelRequest].
  BmSetLogLevelRequest({
    this.logLevel = LogLevel.none,
    this.logColor = true,
  });

  /// The log level to use.
  LogLevel logLevel;

  /// Whether to colorize log output.
  bool logColor;
}

/// Request to set plugin options.
class BmSetOptionsRequest {
  /// Creates a [BmSetOptionsRequest].
  BmSetOptionsRequest({
    required this.showPowerAlert,
    required this.restoreState,
  });

  /// Whether to show the system alert when Bluetooth is off (iOS and macOS).
  bool showPowerAlert;

  /// Whether to restore the Bluetooth state after the app was relaunched (iOS and macOS).
  bool restoreState;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["show_power_alert"] = showPowerAlert;
    data["restore_state"] = restoreState;
    return data;
  }
}

/// Request to check whether Bluetooth is supported on this device.
class BmIsSupportedRequest {
  /// Creates a [BmIsSupportedRequest].
  BmIsSupportedRequest();
}

/// Request for the PHY support of this device.
class PhySupportRequest {
  /// Creates a [PhySupportRequest].
  PhySupportRequest();
}

/// The LE PHYs supported by this device.
class PhySupport {
  /// Creates a [PhySupport].
  PhySupport({
    required this.le2M,
    required this.leCoded,
  });

  factory PhySupport.fromMap(Map<dynamic, dynamic> json) {
    return PhySupport(
      le2M: json["le_2M"] as bool,
      leCoded: json["le_coded"] as bool,
    );
  }

  /// High speed (PHY 2M)
  final bool le2M;

  /// Long range (PHY codec)
  final bool leCoded;
}

/// Request message for starting an L2CAP server.
///
/// Used internally to communicate with the platform layer when
/// `FlutterBlueMax.listenL2capChannel` is called.
class ListenL2CapChannelRequest {
  /// Creates a new [ListenL2CapChannelRequest]
  ListenL2CapChannelRequest({required this.secure});

  /// Whether to use a secure L2CAP channel
  /// - Android: Uses listenUsingL2capChannel() vs listenUsingInsecureL2capChannel()
  /// - iOS: Uses publishL2CAPChannelWithEncryption(secure)
  final bool secure;

  /// Converts this request to a map for platform communication
  Map<dynamic, dynamic> toMap() {
    return {
      "secure": secure,
    };
  }
}

/// Response message from starting an L2CAP server.
///
/// Contains the PSM (Protocol Service Multiplexer) assigned by the system
/// for the newly created L2CAP server.
class ListenL2CapChannelResponse {
  /// Creates a [ListenL2CapChannelResponse] from a platform message map
  ListenL2CapChannelResponse.fromMap(Map<dynamic, dynamic> map) : psm = map["psm"] as int;

  /// The PSM assigned to the L2CAP server
  final int psm;
}

/// Request message for stopping an L2CAP server.
///
/// Used internally to communicate with the platform layer when
/// `FlutterBlueMax.stopL2capServer` is called.
class StopListenL2CapChannelRequest {
  /// Creates a new [StopListenL2CapChannelRequest]
  StopListenL2CapChannelRequest({required this.psm});

  /// The PSM of the L2CAP server to stop
  final int psm;

  /// Converts this request to a map for platform communication
  Map<dynamic, dynamic> toMap() {
    return {
      "psm": psm,
    };
  }
}

/// Request message for opening an L2CAP channel to a device.
///
/// Used internally to communicate with the platform layer when
/// `BluetoothDevice.openL2CapChannel` is called.
class OpenL2CapChannelRequest {
  /// Creates a new [OpenL2CapChannelRequest]
  OpenL2CapChannelRequest({
    required this.remoteId,
    required this.psm,
    required this.secure,
  });

  /// The device identifier of the target device
  final String remoteId;

  /// The PSM to connect to on the remote device
  final int psm;

  /// Whether to use a secure L2CAP channel
  /// - Android: Uses createL2capChannel() vs createInsecureL2capChannel()
  /// - iOS: Security controlled by server's publishL2CAPChannelWithEncryption setting
  final bool secure;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    return {
      "psm": psm,
      "remote_id": remoteId,
      "secure": secure,
    };
  }
}

/// Request message for closing an L2CAP channel.
///
/// Used internally to communicate with the platform layer when
/// [BluetoothL2capChannel.close] is called.
class CloseL2CapChannelRequest {
  /// Creates a new [CloseL2CapChannelRequest]
  CloseL2CapChannelRequest({
    required this.remoteId,
    required this.psm,
  });

  /// The device identifier of the remote device
  final String remoteId;

  /// The PSM of the channel to close
  final int psm;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    return {
      "psm": psm,
      "remote_id": remoteId,
    };
  }
}

/// Request message for reading data from an L2CAP channel.
///
/// Used internally to communicate with the platform layer when
/// [BluetoothL2capChannel.read] is called.
class ReadL2CapChannelRequest {
  /// Creates a new [ReadL2CapChannelRequest]
  ReadL2CapChannelRequest({
    required this.remoteId,
    required this.psm,
  });

  /// The device identifier of the remote device
  final String remoteId;

  /// The PSM of the channel to read from
  final int psm;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    return {
      "psm": psm,
      "remote_id": remoteId,
    };
  }
}

/// Response message from reading an L2CAP channel.
///
/// Contains the data that was read from the L2CAP channel along with
/// metadata about the read operation.
class ReadL2CapChannelResponse {
  /// Creates a [ReadL2CapChannelResponse] from a platform message map
  ReadL2CapChannelResponse.fromMap(Map<dynamic, dynamic> map)
      : remoteId = map["remote_id"] as String,
        psm = map["psm"] as int,
        bytesRead = map["bytes_read"] as int,
        value = Uint8List.fromList(map["value"] as List<int>);

  /// The device identifier of the remote device
  final String remoteId;

  /// The PSM of the channel that was read from
  final int psm;

  /// The number of bytes that were read
  final int bytesRead;

  /// The actual data bytes that were read
  final List<int> value;
}

/// Request message for writing data to an L2CAP channel.
///
/// Used internally to communicate with the platform layer when
/// [BluetoothL2capChannel.write] is called.
class WriteL2CapChannelRequest {
  /// Creates a new [WriteL2CapChannelRequest]
  WriteL2CapChannelRequest({required this.remoteId, required this.psm, required this.value});

  /// The device identifier of the remote device
  final String remoteId;

  /// The PSM of the channel to write to
  final int psm;

  /// The data bytes to write
  final List<int> value;

  /// Converts this message to a map for platform communication.
  Map<dynamic, dynamic> toMap() {
    return {
      "psm": psm,
      "remote_id": remoteId,
      "value": Uint8List.fromList(value),
    };
  }
}

/// Represents data received on an L2CAP channel.
///
/// This class is used by `FlutterBlueMax.onL2capReceived` to deliver
/// L2CAP data that was received from remote devices. It contains the
/// source device, channel information, and the actual data bytes.
///
/// Example usage:
/// ```dart
/// FlutterBlueMax.onL2capReceived.listen((L2CapChannelData data) {
///   print('Received ${data.value.length} bytes from ${data.remoteId} on PSM ${data.psm}');
///   // Process the data...
/// });
/// ```
class L2CapChannelData {
  /// Creates a new [L2CapChannelData] instance
  L2CapChannelData({required this.remoteId, required this.psm, required this.value});

  /// Creates an [L2CapChannelData] from a platform message map
  factory L2CapChannelData.fromMap(Map<dynamic, dynamic> map) {
    return L2CapChannelData(
      remoteId: DeviceIdentifier(map["remote_id"] as String),
      psm: map["psm"] as int,
      value: Uint8List.fromList(map["value"] as List<int>),
    );
  }

  /// The device identifier of the device that sent this data
  final DeviceIdentifier remoteId;

  /// The PSM (Protocol Service Multiplexer) of the channel this data was received on
  final int psm;

  /// The actual data bytes that were received
  final List<int> value;
}

/// Event emitted when an L2CAP channel is closed by the remote device,
/// a stream error, or a device disconnect.
class L2CapChannelClosed {
  /// Creates a new [L2CapChannelClosed] instance
  L2CapChannelClosed({required this.remoteId, required this.psm});

  /// Creates an [L2CapChannelClosed] from a platform message map
  factory L2CapChannelClosed.fromMap(Map<dynamic, dynamic> map) {
    return L2CapChannelClosed(
      remoteId: DeviceIdentifier(map["remote_id"] as String),
      psm: map["psm"] as int,
    );
  }

  /// The device identifier of the remote device
  final DeviceIdentifier remoteId;

  /// The PSM (Protocol Service Multiplexer) of the channel that was closed
  final int psm;
}

/// Event emitted when a remote device connects to an L2CAP server
/// started with `listenL2capChannel`.
class L2CapChannelConnected {
  /// Creates a new [L2CapChannelConnected] instance
  L2CapChannelConnected({required this.remoteId, required this.psm});

  /// Creates an [L2CapChannelConnected] from a platform message map
  factory L2CapChannelConnected.fromMap(Map<dynamic, dynamic> map) {
    return L2CapChannelConnected(
      remoteId: DeviceIdentifier(map["remote_id"] as String),
      psm: map["psm"] as int,
    );
  }

  /// The identifier to address the accepted channel with.
  ///
  /// On Android this is the connecting client's MAC address. On iOS
  /// CoreBluetooth does not expose which central opened the channel, so the
  /// placeholder id `server` is reported instead — both platforms accept it
  /// for channel operations on server-accepted channels.
  final DeviceIdentifier remoteId;

  /// The PSM (Protocol Service Multiplexer) of the server that was connected to
  final int psm;
}

// random number defined by flutter blue plus.
// Ideally it should not conflict with iOS or Android error codes.
int bmUserCanceledErrorCode = 23789258;
