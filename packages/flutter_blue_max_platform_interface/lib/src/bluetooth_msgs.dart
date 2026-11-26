import "dart:typed_data";

import "package:flutter_blue_max_platform_interface/src/device_identifier.dart";
import "package:flutter_blue_max_platform_interface/src/guid.dart";
import "package:flutter_blue_max_platform_interface/src/log_level.dart";

class BmBluetoothAdapterStateRequest {
  BmBluetoothAdapterStateRequest();
}

enum BmAdapterStateEnum {
  unknown, // 0
  unavailable, // 1
  unauthorized, // 2
  turningOn, // 3
  on, // 4
  turningOff, // 5
  off, // 6
}

class BmBluetoothAdapterState {

  BmBluetoothAdapterState({required this.adapterState});

  factory BmBluetoothAdapterState.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json["adapter_state"] as int],
    );
  }
  BmAdapterStateEnum adapterState;
}

class BmBluetoothAdapterNameRequest {
  BmBluetoothAdapterNameRequest();
}

class BmBluetoothAdapterName {

  BmBluetoothAdapterName({required this.adapterName});
  String adapterName;
}

class BmMsdFilter {
  BmMsdFilter(this.manufacturerId, this.data, this.mask);
  int manufacturerId;
  List<int>? data;
  List<int>? mask;
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map["manufacturer_id"] = manufacturerId;
    map["data"] = Uint8List.fromList(data ?? []);
    map["mask"] = Uint8List.fromList(mask ?? []);
    return map;
  }
}

class BmServiceDataFilter {
  BmServiceDataFilter(this.service, this.data, this.mask);
  Guid service;
  List<int> data;
  List<int> mask;
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map["service"] = service.str;
    map["data"] = Uint8List.fromList(data);
    map["mask"] = Uint8List.fromList(mask);
    return map;
  }
}

class BmScanSettings {

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
  final List<Guid> withServices;
  final List<String> withRemoteIds;
  final List<String> withNames;
  final List<String> withKeywords;
  final List<BmMsdFilter> withMsd;
  final List<BmServiceDataFilter> withServiceData;
  final bool continuousUpdates;
  final int continuousDivisor;
  final bool androidLegacy;
  final int androidScanMode;
  final bool androidUsesFineLocation;
  final bool androidCheckLocationServices;
  final List<Guid> webOptionalServices;

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

class BmStopScanRequest {
  BmStopScanRequest();
}

class BmScanAdvertisement {

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
  final DeviceIdentifier remoteId;
  final String? platformName;
  final String? advName;
  final bool connectable;
  final int? txPowerLevel;
  final int? appearance; // not supported on iOS / macOS
  final Map<int, List<int>> manufacturerData;
  final Map<Guid, List<int>> serviceData;
  final List<Guid> serviceUuids;
  final int rssi;
}

class BmScanResponse {

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
  final List<BmScanAdvertisement> advertisements;
  final bool success;
  final int errorCode;
  final String errorString;
}

class BmConnectRequest {

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });
  DeviceIdentifier remoteId;
  bool autoConnect;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["auto_connect"] = autoConnect ? 1 : 0;
    return data;
  }
}

class BmDisconnectRequest {

  BmDisconnectRequest({
    required this.remoteId,
  });
  DeviceIdentifier remoteId;
}

class BmBluetoothDevice {

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
  DeviceIdentifier remoteId;
  String? platformName;
}

class BmNameChanged {

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
  DeviceIdentifier remoteId;
  String name;
}

class BmBluetoothService {

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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? primaryServiceUuid;
  List<BmBluetoothCharacteristic> characteristics;
}

class BmBluetoothCharacteristic {

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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;
}

class BmBluetoothDescriptor {

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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;
}

class BmCharacteristicProperties {

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
  bool broadcast;
  bool read;
  bool writeWithoutResponse;
  bool write;
  bool notify;
  bool indicate;
  bool authenticatedSignedWrites;
  bool extendedProperties;
  bool notifyEncryptionRequired;
  bool indicateEncryptionRequired;
}

class BmDiscoverServicesRequest {

  BmDiscoverServicesRequest({
    required this.remoteId,
  });
  DeviceIdentifier remoteId;
}

class BmDiscoverServicesResult {

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
  final DeviceIdentifier remoteId;
  final List<BmBluetoothService> services;
  final bool success;
  final int errorCode;
  final String errorString;
}

class BmReadCharacteristicRequest {

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    this.primaryServiceUuid,
    this.instanceId,
  });
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;

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

class BmCharacteristicData {

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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;

  /// null when the platform reports no value, iOS & macOS do so for a failed read
  final List<int>? value;
  final bool success;
  final int errorCode;
  final String errorString;
  final int? instanceId;
}

class BmReadDescriptorRequest {

  BmReadDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
    this.instanceId,
  });
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;

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

enum BmWriteType {
  withResponse,
  withoutResponse,
}

class BmWriteCharacteristicRequest {

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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;
  final BmWriteType writeType;
  final bool allowLongWrite;
  final List<int> value;

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

class BmWriteDescriptorRequest {

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.descriptorUuid,
    this.instanceId,
    required this.value,
  });
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;
  final Guid descriptorUuid;
  final List<int> value;

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

class BmDescriptorData {

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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;
}

class BmSetNotifyValueRequest {

  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    this.instanceId,
    required this.forceIndications,
    required this.enable,
  });
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final int? instanceId;
  final bool forceIndications;
  final bool enable;

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

enum BmConnectionStateEnum {
  disconnected, // 0
  connected, // 1
}

class BmConnectionStateResponse {

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
  final DeviceIdentifier remoteId;
  final BmConnectionStateEnum connectionState;
  final int? disconnectReasonCode;
  final String? disconnectReasonString;
}

class BmBondedDevicesRequest {
  BmBondedDevicesRequest();
}

class BmSystemDevicesRequest {

  BmSystemDevicesRequest({
    required this.withServices,
  });
  final List<Guid> withServices;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["with_services"] = withServices.map((s) => s.str).toList();
    return data;
  }
}

class BmDevicesList {

  BmDevicesList({required this.devices});

  factory BmDevicesList.fromMap(Map<dynamic, dynamic> json) {
    // convert to BmBluetoothDevice
    final List<BmBluetoothDevice> devices = [];
    for (final device in json["devices"] as List<dynamic>) {
      devices.add(BmBluetoothDevice.fromMap(device as Map<dynamic, dynamic>));
    }
    return BmDevicesList(devices: devices);
  }
  final List<BmBluetoothDevice> devices;
}

class BmMtuChangeRequest {

  BmMtuChangeRequest({required this.remoteId, required this.mtu});
  final DeviceIdentifier remoteId;
  final int mtu;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["mtu"] = mtu;
    return data;
  }
}

class BmMtuChangedResponse {

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
  final DeviceIdentifier remoteId;
  final int mtu;
  final bool success;
  final int errorCode;
  final String errorString;
}

class BmReadRssiRequest {

  BmReadRssiRequest({
    required this.remoteId,
  });
  DeviceIdentifier remoteId;
}

class BmReadRssiResult {

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
  final DeviceIdentifier remoteId;
  final int rssi;
  final bool success;
  final int errorCode;
  final String errorString;
}

enum BmConnectionPriorityEnum {
  balanced, // 0
  high, // 1
  lowPower, // 2
}

class BmConnectionPriorityRequest {

  BmConnectionPriorityRequest({
    required this.remoteId,
    required this.connectionPriority,
  });
  final DeviceIdentifier remoteId;
  final BmConnectionPriorityEnum connectionPriority;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["connection_priority"] = connectionPriority.index;
    return data;
  }
}

class BmPreferredPhy {

  BmPreferredPhy({
    required this.remoteId,
    required this.txPhy,
    required this.rxPhy,
    required this.phyOptions,
  });
  final DeviceIdentifier remoteId;
  final int txPhy;
  final int rxPhy;
  final int phyOptions;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["tx_phy"] = txPhy;
    data["rx_phy"] = rxPhy;
    data["phy_options"] = phyOptions;
    return data;
  }
}

class BmBondStateRequest {

  BmBondStateRequest({
    required this.remoteId,
  });
  DeviceIdentifier remoteId;
}

enum BmBondStateEnum {
  none, // 0
  bonding, // 1
  bonded, // 2
}

class BmBondStateResponse {

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
  final DeviceIdentifier remoteId;
  final BmBondStateEnum bondState;
  final BmBondStateEnum? prevState;
}

class BmCreateBondRequest {

  BmCreateBondRequest({
    required this.remoteId,
    required this.pin,
  });
  DeviceIdentifier remoteId;
  Uint8List? pin;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["remote_id"] = remoteId.str;
    data["pin"] = pin;
    return data;
  }
}

class BmRemoveBondRequest {

  BmRemoveBondRequest({
    required this.remoteId,
  });
  DeviceIdentifier remoteId;
}

class BmClearGattCacheRequest {

  BmClearGattCacheRequest({
    required this.remoteId,
  });
  DeviceIdentifier remoteId;
}

class BmDetachedFromEngineResponse {
  BmDetachedFromEngineResponse();
}

class BmTurnOffRequest {
  BmTurnOffRequest();
}

class BmTurnOnRequest {
  BmTurnOnRequest();
}

class BmTurnOnResponse {

  BmTurnOnResponse({
    required this.userAccepted,
  });

  factory BmTurnOnResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmTurnOnResponse(
      userAccepted: json["user_accepted"] as bool,
    );
  }
  bool userAccepted;
}

class BmSetLogLevelRequest {

  BmSetLogLevelRequest({
    this.logLevel = LogLevel.none,
    this.logColor = true,
  });
  LogLevel logLevel;
  bool logColor;
}

class BmSetOptionsRequest {

  BmSetOptionsRequest({
    required this.showPowerAlert,
    required this.restoreState,
  });
  bool showPowerAlert;
  bool restoreState;

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data["show_power_alert"] = showPowerAlert;
    data["restore_state"] = restoreState;
    return data;
  }
}

class BmIsSupportedRequest {
  BmIsSupportedRequest();
}

class PhySupportRequest {
  PhySupportRequest();
}

class PhySupport {

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
/// [FlutterBlueMax.listenL2capChannel] is called.
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
/// [FlutterBlueMax.stopL2capServer] is called.
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
/// [BluetoothDevice.openL2CapChannel] is called.
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
/// This class is used by [FlutterBlueMax.onL2capReceived] to deliver
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
