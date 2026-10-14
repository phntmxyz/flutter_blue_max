import 'dart:async';

import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';

/// Replaces only native I/O; the example and the public plugin run unchanged.
final class FakeBluetoothPlatform extends FlutterBlueMaxPlatform {
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

  @override
  Future<BmBluetoothAdapterState> getAdapterState(BmBluetoothAdapterStateRequest request) async =>
      BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);
  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) async => true;
  @override
  Future<bool> startScan(BmScanSettings request) async => true;
  @override
  Future<bool> stopScan(BmStopScanRequest request) async => true;

  void advertise({String id = 'AA:BB:CC:DD:EE:01', String name = 'Test peripheral', int rssi = -45}) {
    advertisements.add(
      BmScanResponse(
        advertisements: [
          BmScanAdvertisement(
            remoteId: DeviceIdentifier(id),
            platformName: name,
            advName: name,
            connectable: true,
            txPowerLevel: null,
            appearance: null,
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

  @override
  Future<bool> connect(BmConnectRequest request) async {
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

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
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

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) async {
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
                descriptors: [],
                properties: BmCharacteristicProperties(
                  broadcast: false,
                  read: true,
                  writeWithoutResponse: true,
                  write: false,
                  notify: false,
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

  @override
  Future<int> listenL2CapChannel(ListenL2CapChannelRequest request) async {
    serverStarts++;
    return pendingServer?.future ?? 129;
  }

  @override
  Future<bool> readCharacteristic(BmReadCharacteristicRequest request) async {
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

  @override
  Future<bool> writeCharacteristic(BmWriteCharacteristicRequest request) async {
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

  @override
  Future<void> stopL2capServer(StopListenL2CapChannelRequest request) async {
    stoppedServers.add(request.psm);
  }

  @override
  Future<void> openL2CapChannel(OpenL2CapChannelRequest request) async {}

  @override
  Future<void> closeL2CapChannel(CloseL2CapChannelRequest request) async {
    closeRequests.add(request);
    closed.add(L2CapChannelClosed(remoteId: DeviceIdentifier(request.remoteId), psm: request.psm));
  }

  @override
  Future<void> writeL2CapChannel(WriteL2CapChannelRequest request) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Peer rejected the write');
    }
    writes.add(request);
  }
}
