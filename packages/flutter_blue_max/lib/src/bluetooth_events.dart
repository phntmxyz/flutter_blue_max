part of "../flutter_blue_max.dart";

class BluetoothEvents {
  Stream<OnConnectionStateChangedEvent> get onConnectionStateChanged {
    return FlutterBlueMaxPlatform.instance.onConnectionStateChanged.map((p) => OnConnectionStateChangedEvent(p));
  }

  Stream<OnMtuChangedEvent> get onMtuChanged {
    return FlutterBlueMaxPlatform.instance.onMtuChanged.map((p) => OnMtuChangedEvent(p));
  }

  Stream<OnReadRssiEvent> get onReadRssi {
    return FlutterBlueMaxPlatform.instance.onReadRssi.map((p) => OnReadRssiEvent(p));
  }

  Stream<OnServicesResetEvent> get onServicesReset {
    return FlutterBlueMaxPlatform.instance.onServicesReset.map((p) => OnServicesResetEvent(p));
  }

  Stream<OnDiscoveredServicesEvent> get onDiscoveredServices {
    return FlutterBlueMaxPlatform.instance.onDiscoveredServices.map((p) => OnDiscoveredServicesEvent(p));
  }

  Stream<OnCharacteristicReceivedEvent> get onCharacteristicReceived {
    // a response without a value is not an event, iOS & macOS send none for a failed read
    return FlutterBlueMaxPlatform.instance.onCharacteristicReceived
        .where((p) => p.value != null)
        .map((p) => OnCharacteristicReceivedEvent(p));
  }

  Stream<OnCharacteristicWrittenEvent> get onCharacteristicWritten {
    return FlutterBlueMaxPlatform.instance.onCharacteristicWritten
        .where((p) => p.value != null)
        .map((p) => OnCharacteristicWrittenEvent(p));
  }

  Stream<OnDescriptorReadEvent> get onDescriptorRead {
    return FlutterBlueMaxPlatform.instance.onDescriptorRead.map((p) => OnDescriptorReadEvent(p));
  }

  Stream<OnDescriptorWrittenEvent> get onDescriptorWritten {
    return FlutterBlueMaxPlatform.instance.onDescriptorWritten.map((p) => OnDescriptorWrittenEvent(p));
  }

  Stream<OnNameChangedEvent> get onNameChanged {
    return FlutterBlueMaxPlatform.instance.onNameChanged.map((p) => OnNameChangedEvent(p));
  }

  Stream<OnBondStateChangedEvent> get onBondStateChanged {
    return FlutterBlueMaxPlatform.instance.onBondStateChanged.map((p) => OnBondStateChangedEvent(p));
  }
}

@Deprecated("Use FbmError instead")
typedef FbpError = FbmError;

class FbmError {
  FbmError(this.errorCode, this.errorString);
  final int errorCode;
  final String errorString;
  ErrorPlatform get platform => _nativeError;
}

//
// Event Classes
//

// On Connection State Changed
class OnConnectionStateChangedEvent {

  OnConnectionStateChangedEvent(this._response);
  final BmConnectionStateResponse _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new connection state
  BluetoothConnectionState get connectionState => _bmToConnectionState(_response.connectionState);
}

// On Mtu Changed
class OnMtuChangedEvent {

  OnMtuChangedEvent(this._response);
  final BmMtuChangedResponse _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new mtu
  int get mtu => _response.mtu;

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Read Rssi
class OnReadRssiEvent {

  OnReadRssiEvent(this._response);
  final BmReadRssiResult _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// rssi
  int get rssi => _response.rssi;

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Services Reset
class OnServicesResetEvent {

  OnServicesResetEvent(this._response);
  final BmBluetoothDevice _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);
}

// On Discovered Services
class OnDiscoveredServicesEvent {

  OnDiscoveredServicesEvent(this._response);
  final BmDiscoverServicesResult _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the discovered services
  List<BluetoothService> get services => _response.services.map((p) => BluetoothService.fromProto(p)).toList();

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Characteristic Received
class OnCharacteristicReceivedEvent {

  OnCharacteristicReceivedEvent(this._response);
  final BmCharacteristicData _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => BluetoothCharacteristic(
      remoteId: _response.remoteId,
      characteristicUuid: _response.characteristicUuid,
      serviceUuid: _response.serviceUuid,
      primaryServiceUuid: _response.primaryServiceUuid);

  /// the new data
  List<int> get value => _response.value!;

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Characteristic Written
class OnCharacteristicWrittenEvent {

  OnCharacteristicWrittenEvent(this._response);
  final BmCharacteristicData _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => BluetoothCharacteristic(
      remoteId: _response.remoteId,
      characteristicUuid: _response.characteristicUuid,
      serviceUuid: _response.serviceUuid,
      primaryServiceUuid: _response.primaryServiceUuid);

  /// the new data
  List<int> get value => _response.value!;

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Descriptor Received
class OnDescriptorReadEvent {

  OnDescriptorReadEvent(this._response);
  final BmDescriptorData _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant descriptor
  BluetoothDescriptor get descriptor => BluetoothDescriptor(
      remoteId: _response.remoteId,
      serviceUuid: _response.serviceUuid,
      characteristicUuid: _response.characteristicUuid,
      descriptorUuid: _response.descriptorUuid);

  /// the new data
  List<int> get value => _response.value;

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Descriptor Written
class OnDescriptorWrittenEvent {

  OnDescriptorWrittenEvent(this._response);
  final BmDescriptorData _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant descriptor
  BluetoothDescriptor get descriptor => BluetoothDescriptor(
      remoteId: _response.remoteId,
      serviceUuid: _response.serviceUuid,
      characteristicUuid: _response.characteristicUuid,
      descriptorUuid: _response.descriptorUuid);

  /// the new data
  List<int> get value => _response.value;

  /// failed?
  FbmError? get error => _response.success ? null : FbmError(_response.errorCode, _response.errorString);
}

// On Name Changed
class OnNameChangedEvent {

  OnNameChangedEvent(this._response);
  final BmNameChanged _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new name
  String? get name => _response.name;
}

// On Bond State Changed
class OnBondStateChangedEvent {

  OnBondStateChangedEvent(this._response);
  final BmBondStateResponse _response;

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
}
