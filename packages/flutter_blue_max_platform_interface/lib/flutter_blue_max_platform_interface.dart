import "dart:async";

import "package:flutter_blue_max_platform_interface/src/bluetooth_msgs.dart";

export "src/bluetooth_msgs.dart";
export "src/device_identifier.dart";
export "src/guid.dart";
export "src/log_level.dart";

/// The interface that implementations of flutter_blue_max must implement.
abstract base class FlutterBlueMaxPlatform {
  static FlutterBlueMaxPlatform? _instance;

  /// The default instance of [FlutterBlueMaxPlatform] to use. Throws an [UnsupportedError] if flutter_blue_max is unsupported on this platform.
  static FlutterBlueMaxPlatform get instance {
    final instance = _instance;

    if (instance != null) {
      return instance;
    } else {
      throw UnsupportedError(
        "flutter_blue_max is unsupported on this platform",
      );
    }
  }

  /// Platform-specific plugins should set this with their own platform-specific class that extends [FlutterBlueMaxPlatform] when they register themselves.
  static set instance(
    FlutterBlueMaxPlatform instance,
  ) {
    _instance = instance;
  }

  /// Emits when the state of the Bluetooth adapter changed.
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return const Stream.empty();
  }

  /// Emits when the bond state of a device changed.
  Stream<BmBondStateResponse> get onBondStateChanged {
    return const Stream.empty();
  }

  /// Emits when a characteristic was read or a notification or indication was received.
  Stream<BmCharacteristicData> get onCharacteristicReceived {
    return const Stream.empty();
  }

  /// Emits when a characteristic write completed.
  Stream<BmCharacteristicData> get onCharacteristicWritten {
    return const Stream.empty();
  }

  /// Emits when the connection state of a device changed.
  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    return const Stream.empty();
  }

  /// Emits when a descriptor read completed.
  Stream<BmDescriptorData> get onDescriptorRead {
    return const Stream.empty();
  }

  /// Emits when a descriptor write completed.
  Stream<BmDescriptorData> get onDescriptorWritten {
    return const Stream.empty();
  }

  /// Emits when the plugin is detached from the Flutter engine.
  Stream<BmDetachedFromEngineResponse> get onDetachedFromEngine {
    return const Stream.empty();
  }

  /// Emits when a service discovery completed.
  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    return const Stream.empty();
  }

  /// Emits when the MTU of a connection changed.
  Stream<BmMtuChangedResponse> get onMtuChanged {
    return const Stream.empty();
  }

  /// Emits when the name of a device changed.
  Stream<BmNameChanged> get onNameChanged {
    return const Stream.empty();
  }

  /// Emits when an RSSI read completed.
  Stream<BmReadRssiResult> get onReadRssi {
    return const Stream.empty();
  }

  /// Emits the advertisements received while scanning.
  Stream<BmScanResponse> get onScanResponse {
    return const Stream.empty();
  }

  /// Emits data received on an L2CAP channel.
  Stream<L2CapChannelData> get onL2CapChannelReceived {
    return const Stream.empty();
  }

  /// Emits when an L2CAP channel was closed.
  Stream<L2CapChannelClosed> get onL2CapChannelClosed {
    return const Stream.empty();
  }

  /// Emits when a remote device connected to an L2CAP server.
  Stream<L2CapChannelConnected> get onL2CapChannelConnected {
    return const Stream.empty();
  }

  /// Emits when the services of a device changed and need to be discovered again.
  Stream<BmBluetoothDevice> get onServicesReset {
    return const Stream.empty();
  }

  /// Emits the response to a request to turn the adapter on.
  Stream<BmTurnOnResponse> get onTurnOnResponse {
    return const Stream.empty();
  }

  static final _logsController = StreamController<String>.broadcast();

  /// Stream of the messages logged through [log].
  static Stream<String> get logs => _logsController.stream;

  /// Adds [s] to [logs] and prints it.
  static void log(String s) {
    _logsController.add(s);
    // ignore: avoid_print
    print(s);
  }

  /// Clears the GATT cache of a device. Returns whether the request was accepted.
  Future<bool> clearGattCache(
    BmClearGattCacheRequest request,
  ) {
    return Future.value(false);
  }

  /// Closes an L2CAP channel.
  Future<void> closeL2CapChannel(
    CloseL2CapChannelRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Connects to a device. Returns whether the request was accepted.
  Future<bool> connect(
    BmConnectRequest request,
  ) {
    return Future.value(false);
  }

  /// Bonds with a device. Returns whether the request was accepted.
  Future<bool> createBond(
    BmCreateBondRequest request,
  ) {
    return Future.value(false);
  }

  /// Disconnects from a device. Returns whether the request was accepted.
  Future<bool> disconnect(
    BmDisconnectRequest request,
  ) {
    return Future.value(false);
  }

  /// Discovers the services of a device, the result is emitted on [onDiscoveredServices].
  Future<bool> discoverServices(
    BmDiscoverServicesRequest request,
  ) {
    return Future.value(false);
  }

  /// Returns the name of the Bluetooth adapter.
  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) {
    return Future.value(
      BmBluetoothAdapterName(
        adapterName: "",
      ),
    );
  }

  /// Returns the current state of the Bluetooth adapter.
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) {
    return Future.value(
      BmBluetoothAdapterState(
        adapterState: BmAdapterStateEnum.unknown,
      ),
    );
  }

  /// Returns the bond state of a device.
  Future<BmBondStateResponse> getBondState(
    BmBondStateRequest request,
  ) {
    return Future.value(
      BmBondStateResponse(
        remoteId: request.remoteId,
        bondState: BmBondStateEnum.none,
        prevState: null,
      ),
    );
  }

  /// Returns the bonded devices.
  Future<BmDevicesList> getBondedDevices(
    BmBondedDevicesRequest request,
  ) {
    return Future.value(
      BmDevicesList(
        devices: const [],
      ),
    );
  }

  /// Returns which LE PHYs this device supports.
  Future<PhySupport> getPhySupport(
    PhySupportRequest request,
  ) {
    return Future.value(
      PhySupport(
        le2M: false,
        leCoded: false,
      ),
    );
  }

  /// Returns the devices already connected to the system.
  Future<BmDevicesList> getSystemDevices(
    BmSystemDevicesRequest request,
  ) {
    return Future.value(
      BmDevicesList(
        devices: const [],
      ),
    );
  }

  /// Returns whether Bluetooth is supported on this device.
  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) {
    return Future.value(false);
  }

  /// Starts an L2CAP server and returns the PSM assigned to it.
  Future<int> listenL2CapChannel(
    ListenL2CapChannelRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Opens an L2CAP channel to a device.
  Future<void> openL2CapChannel(
    OpenL2CapChannelRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Reads a characteristic, the result is emitted on [onCharacteristicReceived].
  Future<bool> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) {
    return Future.value(false);
  }

  /// Reads a descriptor, the result is emitted on [onDescriptorRead].
  Future<bool> readDescriptor(
    BmReadDescriptorRequest request,
  ) {
    return Future.value(false);
  }

  /// Reads data from an L2CAP channel.
  Future<List<int>> readL2CapChannel(
    ReadL2CapChannelRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Reads the RSSI of a device, the result is emitted on [onReadRssi].
  Future<bool> readRssi(
    BmReadRssiRequest request,
  ) {
    return Future.value(false);
  }

  /// Removes the bond with a device. Returns whether the request was accepted.
  Future<bool> removeBond(
    BmRemoveBondRequest request,
  ) {
    return Future.value(false);
  }

  /// Requests a connection priority. Returns whether the request was accepted.
  Future<bool> requestConnectionPriority(
    BmConnectionPriorityRequest request,
  ) {
    return Future.value(false);
  }

  /// Requests an MTU, the result is emitted on [onMtuChanged].
  Future<bool> requestMtu(
    BmMtuChangeRequest request,
  ) {
    return Future.value(false);
  }

  /// Sets the log level of the platform layer.
  Future<bool> setLogLevel(
    BmSetLogLevelRequest request,
  ) {
    return Future.value(false);
  }

  /// Enables or disables notifications or indications of a characteristic.
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) {
    return Future.value(false);
  }

  /// Sets plugin options.
  Future<bool> setOptions(
    BmSetOptionsRequest request,
  ) {
    return Future.value(false);
  }

  /// Sets the preferred PHY of a connection.
  Future<bool> setPreferredPhy(
    BmPreferredPhy request,
  ) {
    return Future.value(false);
  }

  /// Starts scanning, results are emitted on [onScanResponse].
  Future<bool> startScan(
    BmScanSettings request,
  ) {
    return Future.value(false);
  }

  /// Stops an L2CAP server.
  Future<void> stopL2capServer(
    StopListenL2CapChannelRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Stops scanning.
  Future<bool> stopScan(
    BmStopScanRequest request,
  ) {
    return Future.value(false);
  }

  /// Turns the Bluetooth adapter off.
  Future<bool> turnOff(
    BmTurnOffRequest request,
  ) {
    return Future.value(false);
  }

  /// Turns the Bluetooth adapter on, the response is emitted on [onTurnOnResponse].
  Future<bool> turnOn(
    BmTurnOnRequest request,
  ) {
    return Future.value(false);
  }

  /// Writes a characteristic, the result is emitted on [onCharacteristicWritten].
  Future<bool> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) {
    return Future.value(false);
  }

  /// Writes a descriptor, the result is emitted on [onDescriptorWritten].
  Future<bool> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) {
    return Future.value(false);
  }

  /// Writes data to an L2CAP channel.
  Future<void> writeL2CapChannel(
    WriteL2CapChannelRequest request,
  ) {
    throw UnimplementedError();
  }
}
