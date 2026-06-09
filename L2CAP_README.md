# L2CAP Implementation - Flutter Blue Plus

Flutter Blue Plus provides comprehensive L2CAP (Logical Link Control and Adaptation Protocol) support with full cross-platform compatibility and object-oriented design that seamlessly integrates with the library's existing architecture.

## Features

- ✅ **Full Cross-Platform Support**: iOS client connections, Android client/server operations
- ✅ **Object-Oriented Design**: Dedicated `BluetoothL2capChannel` objects for clean API
- ✅ **Complete Server Management**: Start/stop L2CAP servers with PSM-specific control
- ✅ **Comprehensive Event Handling**: 5 different event types for complete lifecycle tracking
- ✅ **Secure & Insecure Channels**: Support for both secure and insecure L2CAP connections
- ✅ **Auto PSM Assignment**: Automatic PSM assignment for server operations
- ✅ **Stream-Based Data Handling**: Efficient data transfer with stream management

## Architecture Overview

L2CAP follows the same object-oriented patterns as all other Flutter Blue Plus functionality:

1. **Device Operations** → Return dedicated objects
2. **Object Encapsulation** → Operations belong to objects, not devices  
3. **Parameter Elimination** → No repetitive parameter passing
4. **Consistent Error Handling** → Same exception patterns as characteristics/services

## Quick Start

### Server (Listening for Connections)

```dart
import 'package:flutter_blue_max/flutter_blue_max.dart';

// Start L2CAP server
int psm = await FlutterBlueMax.listenL2capChannel(secure: true);
print('L2CAP server listening on PSM: $psm');

// Listen for incoming data
FlutterBlueMax.onL2capReceived.listen((data) {
  print('Received ${data.bytes.length} bytes from ${data.remoteId}');
  // Handle incoming data
});

// Stop server when done
await FlutterBlueMax.stopL2capServer(psm);
```

### Client (Connecting to Server)

```dart
// Connect to device first
await device.connect();

// Open L2CAP channel
BluetoothL2capChannel channel = await device.openL2CapChannel(1234, secure: true);

// Write data
await channel.write([0x01, 0x02, 0x03, 0x04]);

// Read data
List<int> response = await channel.read();

// Close channel
await channel.close();
```

## API Reference

### FlutterBlueMax (Static Methods)

#### `listenL2capChannel({bool secure = true})`
Starts an L2CAP server listening for incoming connections.

- **Parameters:**
  - `secure`: Whether to use secure L2CAP channel (default: true)
- **Returns:** `Future<int>` - The assigned PSM
- **Platform:** iOS 11.0+, Android

```dart
int psm = await FlutterBlueMax.listenL2capChannel(secure: true);
```

#### `stopL2capServer(int psm)`
Stops an L2CAP server by PSM.

- **Parameters:**
  - `psm`: The PSM of the server to stop
- **Returns:** `Future<void>`
- **Platform:** iOS 11.0+, Android

```dart
await FlutterBlueMax.stopL2capServer(psm);
```

### BluetoothDevice

#### `openL2CapChannel(int psm, {bool secure = true})`
Opens an L2CAP channel to the connected device.

- **Parameters:**
  - `psm`: Protocol Service Multiplexer to connect to
  - `secure`: Whether to use secure L2CAP channel (default: true)
- **Returns:** `Future<BluetoothL2capChannel>`
- **Throws:** `FlutterBlueMaxException` if device not connected
- **Platform:** iOS 11.0+, Android

```dart
BluetoothL2capChannel channel = await device.openL2CapChannel(1234, secure: true);
```

### BluetoothL2capChannel

The `BluetoothL2capChannel` class encapsulates an L2CAP channel connection and provides methods for data transfer.

#### Properties
- `DeviceIdentifier deviceId` - The device this channel connects to
- `int psm` - The Protocol Service Multiplexer for this channel

#### `write(List<int> data)`
Writes data to the L2CAP channel.

- **Parameters:**
  - `data`: List of bytes to write
- **Returns:** `Future<void>`
- **Throws:** `FlutterBlueMaxException` on write failure

```dart
await channel.write([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello"
```

#### `read()`
Reads available data from the L2CAP channel.

- **Returns:** `Future<List<int>>` - The received bytes
- **Throws:** `FlutterBlueMaxException` if channel not found

```dart
List<int> data = await channel.read();
String message = String.fromCharCodes(data);
```

#### `close()`
Closes the L2CAP channel and releases resources.

- **Returns:** `Future<void>`

```dart
await channel.close();
```

## Event Streams

Flutter Blue Plus provides comprehensive event streams for L2CAP operations:

### `FlutterBlueMax.onL2capReceived`
Stream of incoming L2CAP data.

```dart
FlutterBlueMax.onL2capReceived.listen((L2CapChannelData data) {
  print('Device: ${data.remoteId}');
  print('PSM: ${data.psm}');  
  print('Data: ${data.bytes}');
});
```

### Platform Events (iOS/Darwin)
Additional events available on iOS platform:

- `OnL2CapChannelOpened` - Channel connection established
- `OnL2CapChannelClosed` - Channel connection closed
- `OnL2CapChannelPublished` - Server started listening
- `OnL2CapChannelUnpublished` - Server stopped listening
- `OnL2CapChannelReceived` - Data received on channel

## Platform Support

| Platform | Client Support | Server Support | Minimum Version |
|----------|----------------|----------------|-----------------|
| **iOS**     | ✅ Full        | ✅ Full        | iOS 11.0       |
| **Android** | ✅ Full        | ✅ Full        | Android API 21  |
| **Web**     | ❌ Not supported | ❌ Not supported | N/A           |

## Complete Example

```dart
import 'package:flutter_blue_max/flutter_blue_max.dart';

class L2CAPExample {
  int? serverPsm;
  BluetoothL2capChannel? clientChannel;

  // Start L2CAP server
  Future<void> startServer() async {
    serverPsm = await FlutterBlueMax.listenL2capChannel(secure: true);
    print('L2CAP server started on PSM: $serverPsm');
    
    // Listen for incoming data
    FlutterBlueMax.onL2capReceived.listen((data) {
      print('Server received: ${String.fromCharCodes(data.bytes)}');
      print('From device: ${data.remoteId}, PSM: ${data.psm}');
    });
  }

  // Connect as client
  Future<void> connectClient(BluetoothDevice device) async {
    // Ensure device is connected
    if (device.isDisconnected) {
      await device.connect();
    }

    // Open L2CAP channel
    clientChannel = await device.openL2CapChannel(serverPsm!, secure: true);
    
    // Send data
    String message = "Hello from L2CAP client!";
    await clientChannel!.write(message.codeUnits);
    
    // Read response (if expected)
    try {
      List<int> response = await clientChannel!.read();
      print('Client received: ${String.fromCharCodes(response)}');
    } catch (e) {
      print('No immediate response: $e');
    }
  }

  // Cleanup
  Future<void> cleanup() async {
    // Close client channel
    if (clientChannel != null) {
      await clientChannel!.close();
      clientChannel = null;
    }
    
    // Stop server
    if (serverPsm != null) {
      await FlutterBlueMax.stopL2capServer(serverPsm!);
      serverPsm = null;
    }
  }
}
```

## Error Handling

L2CAP methods follow the same error handling patterns as other Flutter Blue Plus operations:

```dart
try {
  BluetoothL2capChannel channel = await device.openL2CapChannel(1234);
} catch (e) {
  if (e is FlutterBlueMaxException) {
    switch (e.errorCode) {
      case FbpErrorCode.deviceIsDisconnected.index:
        print('Device not connected');
        break;
      case FbpErrorCode.applePlatformOnly.index:
        print('L2CAP not supported on this platform');
        break;
      default:
        print('L2CAP error: ${e.description}');
    }
  }
}
```

## Best Practices

1. **Always check device connection** before opening L2CAP channels
2. **Close channels explicitly** to free resources
3. **Stop servers when done** to prevent resource leaks  
4. **Handle platform limitations** (check for web/unsupported platforms)
5. **Use secure channels** unless specifically needing insecure connections
6. **Implement proper error handling** for connection failures
7. **Listen to event streams** for incoming data and connection state changes

## Architecture Alignment

L2CAP implementation follows the exact same patterns as Flutter Blue Plus characteristics and services:

- **Object Creation**: `device.openL2CapChannel()` → returns channel object (like `device.discoverServices()`)
- **Object Operations**: `channel.read()`, `channel.write()` (like `characteristic.read()`)
- **Resource Management**: `channel.close()` for explicit cleanup
- **Error Handling**: Same exception types and patterns
- **Platform Abstraction**: Same underlying platform interface

This ensures L2CAP feels natural and familiar to existing Flutter Blue Plus developers.