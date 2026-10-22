import 'dart:async';

import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';

/// Replaces only native I/O; the example and the public plugin run unchanged.
final class FakeBluetoothPlatform() extends FlutterBlueMaxPlatform {
  final adapters = StreamController<BmBluetoothAdapterState>.broadcast(sync: true);
  final connections = StreamController<BmConnectionStateResponse>.broadcast(sync: true);
  final advertisements = StreamController<BmScanResponse>.broadcast(sync: true);
  final discoveries = StreamController<BmDiscoverServicesResult>.broadcast(sync: true);
  final characteristicValues = StreamController<BmCharacteristicData>.broadcast(sync: true);
  final characteristicWritten = StreamController<BmCharacteristicData>.broadcast(sync: true);
  final characteristicWrites = <BmWriteCharacteristicRequest>[];
  final accepted = StreamController<L2CapChannelConnected>.broadcast(sync: true);
  final received = StreamController<L2CapChannelData>.broadcast(sync: true);
  final closed = StreamController<L2CapChannelClosed>.broadcast(sync: true);
  final writes = <WriteL2CapChannelRequest>[];
  final closeRequests = <CloseL2CapChannelRequest>[];
  final stoppedServers = <int>[];
  final connected = <DeviceIdentifier>{};
  Completer<int>? pendingServer;
  bool failNextWrite = false;
  int serverStarts = 0;
  bool holdConnections = false;
  bool includeGattExtras = false;
  bool emitNotifyDescriptorEvents = true;
  bool failNextOpen = false;
  bool disconnectOnOpenFailure = false;
  Object? l2capFailure;
  final connectRequests = <BmConnectRequest>[];
  final systemDeviceRequests = <BmSystemDevicesRequest>[];
  final scanRequests = <BmScanSettings>[];
  final rssiRequests = <BmReadRssiRequest>[];
  final openRequests = <OpenL2CapChannelRequest>[];
  final readRequests = <ReadL2CapChannelRequest>[];
  final characteristicReads = <BmReadCharacteristicRequest>[];
  final descriptorWrites = <BmWriteDescriptorRequest>[];
  final notifyRequests = <BmSetNotifyValueRequest>[];
  final systemPeers = <BmBluetoothDevice>[];
  final rssiValues = StreamController<BmReadRssiResult>.broadcast(sync: true);
  final descriptorRead = StreamController<BmDescriptorData>.broadcast(sync: true);
  final descriptorWritten = StreamController<BmDescriptorData>.broadcast(sync: true);
  final turnOnResponses = StreamController<BmTurnOnResponse>.broadcast(sync: true);
  List<int> bufferedBytes = [];
  Completer<void>? pendingWrites;
  int turnOnRequests = 0;
  int scanStarts = 0;

  /// Clear per-test behavior while preserving the plugin's subscribed streams.
  void reset() {
    characteristicWrites.clear();
    writes.clear();
    closeRequests.clear();
    stoppedServers.clear();
    connected.clear();
    connectRequests.clear();
    systemDeviceRequests.clear();
    scanRequests.clear();
    rssiRequests.clear();
    openRequests.clear();
    readRequests.clear();
    characteristicReads.clear();
    descriptorWrites.clear();
    notifyRequests.clear();
    systemPeers.clear();
    pendingServer = null;
    failNextWrite = false;
    serverStarts = 0;
    holdConnections = false;
    includeGattExtras = false;
    emitNotifyDescriptorEvents = true;
    failNextOpen = false;
    disconnectOnOpenFailure = false;
    l2capFailure = null;
    bufferedBytes = [];
    pendingWrites = null;
    turnOnRequests = 0;
    scanStarts = 0;
    overrideGetAdapterName = null;
    overrideGetSystemDevices = null;
    overrideTurnOn = null;
    overrideReadRssi = null;
    overrideReadL2CapChannel = null;
    overrideReadDescriptor = null;
    overrideWriteDescriptor = null;
    overrideSetNotifyValue = null;
    overrideGetAdapterState = null;
    overrideSetLogLevel = null;
    overrideStartScan = null;
    overrideStopScan = null;
    overrideConnect = null;
    overrideDisconnect = null;
    overrideDiscoverServices = null;
    overrideListenL2CapChannel = null;
    overrideReadCharacteristic = null;
    overrideWriteCharacteristic = null;
    overrideStopL2capServer = null;
    overrideOpenL2CapChannel = null;
    overrideCloseL2CapChannel = null;
    overrideWriteL2CapChannel = null;
  }

  Future<BmBluetoothAdapterName> Function(BmBluetoothAdapterNameRequest request)? overrideGetAdapterName;

  @override
  Future<BmBluetoothAdapterName> getAdapterName(BmBluetoothAdapterNameRequest request) async {
    final override = overrideGetAdapterName;
    if (override != null) {
      return await override(request);
    }
    return BmBluetoothAdapterName(adapterName: 'Test workstation');
  }

  @override
  Stream<BmReadRssiResult> get onReadRssi => rssiValues.stream;
  @override
  Stream<BmDescriptorData> get onDescriptorRead => descriptorRead.stream;
  @override
  Stream<BmDescriptorData> get onDescriptorWritten => descriptorWritten.stream;
  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse => turnOnResponses.stream;

  Future<BmDevicesList> Function(BmSystemDevicesRequest request)? overrideGetSystemDevices;

  @override
  Future<BmDevicesList> getSystemDevices(BmSystemDevicesRequest request) async {
    final override = overrideGetSystemDevices;
    if (override != null) {
      return await override(request);
    }
    systemDeviceRequests.add(request);
    return BmDevicesList(devices: List.of(systemPeers));
  }

  Future<bool> Function(BmTurnOnRequest request)? overrideTurnOn;

  @override
  Future<bool> turnOn(BmTurnOnRequest request) async {
    final override = overrideTurnOn;
    if (override != null) {
      return await override(request);
    }
    turnOnRequests++;
    turnOnResponses.add(BmTurnOnResponse(userAccepted: true));
    adapters.add(BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on));
    return true;
  }

  Future<bool> Function(BmReadRssiRequest request)? overrideReadRssi;

  @override
  Future<bool> readRssi(BmReadRssiRequest request) async {
    final override = overrideReadRssi;
    if (override != null) {
      return await override(request);
    }
    rssiRequests.add(request);
    rssiValues.add(
      BmReadRssiResult(remoteId: request.remoteId, rssi: -47, success: true, errorCode: 0, errorString: ''),
    );
    return true;
  }

  Future<List<int>> Function(ReadL2CapChannelRequest request)? overrideReadL2CapChannel;

  @override
  Future<List<int>> readL2CapChannel(ReadL2CapChannelRequest request) async {
    final override = overrideReadL2CapChannel;
    if (override != null) {
      return await override(request);
    }
    readRequests.add(request);
    final bytes = bufferedBytes;
    bufferedBytes = [];
    return bytes;
  }

  Future<bool> Function(BmReadDescriptorRequest request)? overrideReadDescriptor;

  @override
  Future<bool> readDescriptor(BmReadDescriptorRequest request) async {
    final override = overrideReadDescriptor;
    if (override != null) {
      return await override(request);
    }
    descriptorRead.add(
      BmDescriptorData(
        remoteId: request.remoteId,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        descriptorUuid: request.descriptorUuid,
        primaryServiceUuid: request.primaryServiceUuid,
        instanceId: request.instanceId,
        value: [0x41],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  Future<bool> Function(BmWriteDescriptorRequest request)? overrideWriteDescriptor;

  @override
  Future<bool> writeDescriptor(BmWriteDescriptorRequest request) async {
    final override = overrideWriteDescriptor;
    if (override != null) {
      return await override(request);
    }
    descriptorWrites.add(request);
    descriptorWritten.add(
      BmDescriptorData(
        remoteId: request.remoteId,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        descriptorUuid: request.descriptorUuid,
        primaryServiceUuid: request.primaryServiceUuid,
        instanceId: request.instanceId,
        value: request.value,
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  Future<bool> Function(BmSetNotifyValueRequest request)? overrideSetNotifyValue;

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) async {
    final override = overrideSetNotifyValue;
    if (override != null) {
      return await override(request);
    }
    notifyRequests.add(request);
    if (!emitNotifyDescriptorEvents) {
      return false;
    }
    descriptorWritten.add(
      BmDescriptorData(
        remoteId: request.remoteId,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        descriptorUuid: Guid('2902'),
        primaryServiceUuid: request.primaryServiceUuid,
        instanceId: request.instanceId,
        value: [if (request.enable) 1 else 0, 0],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => adapters.stream;
  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged => connections.stream;
  @override
  Stream<BmScanResponse> get onScanResponse => advertisements.stream;
  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices => discoveries.stream;
  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived => characteristicValues.stream;
  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten => characteristicWritten.stream;
  @override
  Stream<L2CapChannelConnected> get onL2CapChannelConnected => accepted.stream;
  @override
  Stream<L2CapChannelData> get onL2CapChannelReceived => received.stream;
  @override
  Stream<L2CapChannelClosed> get onL2CapChannelClosed => closed.stream;

  Future<BmBluetoothAdapterState> Function(BmBluetoothAdapterStateRequest request)? overrideGetAdapterState;

  @override
  Future<BmBluetoothAdapterState> getAdapterState(BmBluetoothAdapterStateRequest request) async {
    final override = overrideGetAdapterState;
    if (override != null) {
      return await override(request);
    }
    return BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);
  }

  Future<bool> Function(BmSetLogLevelRequest request)? overrideSetLogLevel;

  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) async {
    final override = overrideSetLogLevel;
    if (override != null) {
      return await override(request);
    }
    return true;
  }

  Future<bool> Function(BmScanSettings request)? overrideStartScan;

  @override
  Future<bool> startScan(BmScanSettings request) async {
    final override = overrideStartScan;
    if (override != null) {
      return await override(request);
    }
    scanStarts++;
    scanRequests.add(request);
    return true;
  }

  Future<bool> Function(BmStopScanRequest request)? overrideStopScan;

  @override
  Future<bool> stopScan(BmStopScanRequest request) async {
    final override = overrideStopScan;
    if (override != null) {
      return await override(request);
    }
    return true;
  }

  void advertise({
    String id = 'AA:BB:CC:DD:EE:01',
    String name = 'Test peripheral',
    int rssi = -45,
    bool connectable = true,
    int? appearance,
  }) {
    advertisements.add(
      BmScanResponse(
        advertisements: [
          BmScanAdvertisement(
            remoteId: DeviceIdentifier(id),
            platformName: name,
            advName: name,
            connectable: connectable,
            txPowerLevel: null,
            appearance: appearance,
            manufacturerData: {},
            serviceData: {},
            serviceUuids: [Guid('180F')],
            rssi: rssi,
          ),
        ],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
  }

  Future<bool> Function(BmConnectRequest request)? overrideConnect;

  @override
  Future<bool> connect(BmConnectRequest request) async {
    final override = overrideConnect;
    if (override != null) {
      return await override(request);
    }
    connectRequests.add(request);
    if (holdConnections) {
      return true;
    }
    connected.add(request.remoteId);
    connections.add(
      BmConnectionStateResponse(
        remoteId: request.remoteId,
        connectionState: BmConnectionStateEnum.connected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ),
    );
    return true;
  }

  Future<bool> Function(BmDisconnectRequest request)? overrideDisconnect;

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
    final override = overrideDisconnect;
    if (override != null) {
      return await override(request);
    }
    connected.remove(request.remoteId);
    connections.add(
      BmConnectionStateResponse(
        remoteId: request.remoteId,
        connectionState: BmConnectionStateEnum.disconnected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ),
    );
    return true;
  }

  Future<bool> Function(BmDiscoverServicesRequest request)? overrideDiscoverServices;

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) async {
    final override = overrideDiscoverServices;
    if (override != null) {
      return await override(request);
    }
    discoveries.add(
      BmDiscoverServicesResult(
        remoteId: request.remoteId,
        services: [
          BmBluetoothService(
            remoteId: request.remoteId,
            serviceUuid: Guid('180F'),
            primaryServiceUuid: null,
            characteristics: [
              BmBluetoothCharacteristic(
                remoteId: request.remoteId,
                serviceUuid: Guid('180F'),
                characteristicUuid: Guid('2A19'),
                primaryServiceUuid: null,
                instanceId: 1,
                descriptors: [
                  if (includeGattExtras)
                    for (final uuid in ['2901', '2902'])
                      BmBluetoothDescriptor(
                        remoteId: request.remoteId,
                        serviceUuid: Guid('180F'),
                        characteristicUuid: Guid('2A19'),
                        descriptorUuid: Guid(uuid),
                        primaryServiceUuid: null,
                        instanceId: 1,
                      ),
                ],
                properties: BmCharacteristicProperties(
                  broadcast: false,
                  read: true,
                  writeWithoutResponse: true,
                  write: includeGattExtras,
                  notify: includeGattExtras,
                  indicate: false,
                  authenticatedSignedWrites: false,
                  extendedProperties: false,
                  notifyEncryptionRequired: false,
                  indicateEncryptionRequired: false,
                ),
              ),
            ],
          ),
        ],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  Future<int> Function(ListenL2CapChannelRequest request)? overrideListenL2CapChannel;

  @override
  Future<int> listenL2CapChannel(ListenL2CapChannelRequest request) async {
    final override = overrideListenL2CapChannel;
    if (override != null) {
      return await override(request);
    }
    serverStarts++;
    final failure = l2capFailure;
    if (failure != null) {
      throw failure;
    }
    final pending = pendingServer;
    if (pending != null) {
      return await pending.future;
    }
    return 129;
  }

  Future<bool> Function(BmReadCharacteristicRequest request)? overrideReadCharacteristic;

  @override
  Future<bool> readCharacteristic(BmReadCharacteristicRequest request) async {
    final override = overrideReadCharacteristic;
    if (override != null) {
      return await override(request);
    }
    characteristicReads.add(request);
    characteristicValues.add(
      BmCharacteristicData(
        remoteId: request.remoteId,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        primaryServiceUuid: request.primaryServiceUuid,
        instanceId: request.instanceId,
        value: [0x64],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  Future<bool> Function(BmWriteCharacteristicRequest request)? overrideWriteCharacteristic;

  @override
  Future<bool> writeCharacteristic(BmWriteCharacteristicRequest request) async {
    final override = overrideWriteCharacteristic;
    if (override != null) {
      return await override(request);
    }
    characteristicWrites.add(request);
    characteristicWritten.add(
      BmCharacteristicData(
        remoteId: request.remoteId,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        primaryServiceUuid: request.primaryServiceUuid,
        instanceId: request.instanceId,
        value: request.value,
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  Future<void> Function(StopListenL2CapChannelRequest request)? overrideStopL2capServer;

  @override
  Future<void> stopL2capServer(StopListenL2CapChannelRequest request) async {
    final override = overrideStopL2capServer;
    if (override != null) {
      return await override(request);
    }
    stoppedServers.add(request.psm);
  }

  Future<void> Function(OpenL2CapChannelRequest request)? overrideOpenL2CapChannel;

  @override
  Future<void> openL2CapChannel(OpenL2CapChannelRequest request) async {
    final override = overrideOpenL2CapChannel;
    if (override != null) {
      return await override(request);
    }
    openRequests.add(request);
    final failure = l2capFailure;
    if (failure != null) {
      throw failure;
    }
    if (failNextOpen) {
      failNextOpen = false;
      if (disconnectOnOpenFailure) {
        await disconnect(BmDisconnectRequest(remoteId: DeviceIdentifier(request.remoteId)));
      }
      throw StateError('Temporary channel failure');
    }
  }

  Future<void> Function(CloseL2CapChannelRequest request)? overrideCloseL2CapChannel;

  @override
  Future<void> closeL2CapChannel(CloseL2CapChannelRequest request) async {
    final override = overrideCloseL2CapChannel;
    if (override != null) {
      return await override(request);
    }
    closeRequests.add(request);
    closed.add(L2CapChannelClosed(remoteId: DeviceIdentifier(request.remoteId), psm: request.psm));
  }

  Future<void> Function(WriteL2CapChannelRequest request)? overrideWriteL2CapChannel;

  @override
  Future<void> writeL2CapChannel(WriteL2CapChannelRequest request) async {
    final override = overrideWriteL2CapChannel;
    if (override != null) {
      return await override(request);
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Peer rejected the write');
    }
    writes.add(request);
    await pendingWrites?.future;
  }
}
