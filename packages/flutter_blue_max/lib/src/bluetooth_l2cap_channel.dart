// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../flutter_blue_max.dart';

/// Represents an L2CAP (Logical Link Control and Adaptation Protocol) channel 
/// for communication with a Bluetooth device.
///
/// L2CAP is a protocol in the Bluetooth protocol stack that handles multiplexing, 
/// segmentation and reassembly, and error detection and recovery for higher level protocols.
/// It provides connection-oriented and connectionless data services to upper layer protocols.
///
/// This class provides methods to read, write, and manage L2CAP channel communication.
///
/// Example usage:
/// ```dart
/// // Open an L2CAP channel
/// BluetoothL2capChannel channel = await device.openL2CapChannel(1234);
/// 
/// // Write data to the channel
/// await channel.write([0x01, 0x02, 0x03]);
/// 
/// // Read data from the channel
/// List<int> data = await channel.read();
/// 
/// // Close the channel when done
/// await channel.close();
/// ```
class BluetoothL2capChannel {
  /// The device identifier for the connected Bluetooth device
  final DeviceIdentifier deviceId;
  
  /// The Protocol Service Multiplexer (PSM) value for this L2CAP channel.
  /// PSM values are used to distinguish between different services/protocols
  /// running over L2CAP on the same device.
  final int psm;

  /// Creates a new [BluetoothL2capChannel] instance.
  ///
  /// [deviceId] - The identifier of the Bluetooth device
  /// [psm] - The Protocol Service Multiplexer value for this channel
  BluetoothL2capChannel({required this.deviceId, required this.psm});

  /// Writes data to the L2CAP channel.
  ///
  /// Sends the provided [data] bytes to the remote device over this L2CAP channel.
  /// The data is transmitted as-is without any additional framing or headers.
  ///
  /// [data] - The bytes to send. Can be any list of integers (0-255).
  ///
  /// Throws [FlutterBlueMaxException] if the write operation fails or 
  /// the channel is not open.
  ///
  /// Example:
  /// ```dart
  /// await channel.write([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello" in ASCII
  /// ```
  Future<void> write(List<int> data) async {
    await FlutterBlueMax._invokeMethod(() => FlutterBlueMaxPlatform.instance.writeL2CapChannel(
      WriteL2CapChannelRequest(
        remoteId: deviceId.str,
        psm: psm,
        value: data,
      ),
    ));
  }

  /// Reads data from the L2CAP channel.
  ///
  /// Attempts to read data that has been received on this L2CAP channel.
  /// This is a blocking operation that waits for data to become available.
  ///
  /// Returns a [List<int>] containing the received bytes. The list may be
  /// empty if no data is available.
  ///
  /// Throws [FlutterBlueMaxException] if the read operation fails or 
  /// the channel is not open.
  ///
  /// Note: For real-time data reception, consider using [FlutterBlueMax.onL2capReceived]
  /// stream instead of polling with this method.
  ///
  /// Example:
  /// ```dart
  /// List<int> receivedData = await channel.read();
  /// print('Received ${receivedData.length} bytes');
  /// ```
  Future<List<int>> read() async {
    return await FlutterBlueMax._invokeMethod(() => FlutterBlueMaxPlatform.instance.readL2CapChannel(
      ReadL2CapChannelRequest(remoteId: deviceId.str, psm: psm),
    ));
  }

  /// Closes the L2CAP channel.
  ///
  /// Terminates the L2CAP channel connection with the remote device.
  /// After calling this method, the channel can no longer be used for
  /// reading or writing data.
  ///
  /// It's important to close channels when they are no longer needed to
  /// free up system resources and allow the remote device to clean up
  /// its resources as well.
  ///
  /// Throws [FlutterBlueMaxException] if the close operation fails.
  ///
  /// Example:
  /// ```dart
  /// // Always close channels when done
  /// await channel.close();
  /// ```
  Future<void> close() async {
    await FlutterBlueMax._invokeMethod(() => FlutterBlueMaxPlatform.instance.closeL2CapChannel(
      CloseL2CapChannelRequest(remoteId: deviceId.str, psm: psm),
    ));
  }

  /// Stream of incoming L2CAP channel data.
  ///
  /// This stream emits [L2CapChannelData] events whenever data is received
  /// on this L2CAP channel. Each event contains the [remoteId], [psm],
  /// and the received [value] bytes.
  ///
  /// The stream is filtered to only include data for this specific
  /// device and PSM.
  ///
  /// Example:
  /// ```dart
  /// channel.onL2CapChannelReceived.listen((data) {
  ///   print('Received ${data.length} bytes');
  /// });
  /// ```
  Stream<List<int>> get onL2CapChannelReceived {
    return FlutterBlueMaxPlatform.instance.onL2CapChannelReceived
      .where((d) => d.remoteId == deviceId && d.psm == psm)
      .map((d) => d.value);
  }

  /// Stream that emits an event when this channel dies — because the remote
  /// device closed it, a stream error occurred, or the device disconnected.
  ///
  /// Without listening to this stream there is no way to learn that the
  /// channel is gone other than a failing [write] or [read].
  ///
  /// Note: it does not emit for a local [close] call, and a single close may
  /// be reported more than once in rare cases (e.g. a stream error racing a
  /// device disconnect) — cancel the subscription on the first event if you
  /// only care about the transition.
  ///
  /// Example:
  /// ```dart
  /// channel.onClosed.first.then((_) {
  ///   print('L2CAP channel closed by remote');
  /// });
  /// ```
  Stream<void> get onClosed {
    return FlutterBlueMaxPlatform.instance.onL2CapChannelClosed
      .where((e) => e.remoteId == deviceId && e.psm == psm)
      .map((e) {});
  }

  @override
  String toString() {
    return 'BluetoothL2capChannel{'
        'deviceId: $deviceId, '
        'psm: $psm'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothL2capChannel &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          psm == other.psm;

  @override
  int get hashCode => deviceId.hashCode ^ psm.hashCode;
}