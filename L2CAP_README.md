# L2CAP Implementation - flutter_blue_max

flutter_blue_max provides L2CAP CoC (Connection-oriented Channel) support on iOS and Android, with an object-oriented design that follows the library's existing architecture.

## Features

- ✅ **Client & Server on both platforms**: open channels to a remote PSM, or publish your own
- ✅ **Object-Oriented Design**: dedicated `BluetoothL2capChannel` objects for a clean API
- ✅ **Full Lifecycle Events**: connected, data received, and closed events as Dart streams
- ✅ **Secure & Insecure Channels**: support for both secure and insecure L2CAP connections
- ✅ **Auto PSM Assignment**: the OS assigns a PSM when starting a server
- ✅ **Timeout Protection**: open/listen calls time out instead of blocking the package forever

## Quick Start

### Server (Listening for Connections)

```dart
import 'package:flutter_blue_max/flutter_blue_max.dart';

// Start L2CAP server
int psm = await FlutterBlueMax.listenL2capChannel(secure: true);
print('L2CAP server listening on PSM: $psm');

// A client connected: build a channel handle from the event to talk to it
BluetoothL2capChannel? clientChannel;
FlutterBlueMax.onL2capConnected.listen((evt) {
  clientChannel = BluetoothL2capChannel(deviceId: evt.remoteId, psm: evt.psm);
  clientChannel!.write([0x01, 0x02, 0x03]); // send data back to the client
});

// Listen for incoming data
FlutterBlueMax.onL2capReceived.listen((data) {
  print('Received ${data.value.length} bytes from ${data.remoteId}');
});

// Notice dead channels (client closed, stream error, disconnect)
FlutterBlueMax.onL2capClosed.listen((evt) {
  print('Channel closed: ${evt.remoteId} / PSM ${evt.psm}');
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

// Receive data (preferred over polling with read())
channel.onL2CapChannelReceived.listen((value) {
  print('Received ${value.length} bytes');
});

// Notice when the channel dies
channel.onClosed.first.then((_) => print('Channel closed by remote'));

// Close channel
await channel.close();
```

## API Reference

### FlutterBlueMax (Static Methods)

#### `listenL2capChannel({bool secure = true, int timeout = 15})`
Starts an L2CAP server listening for incoming connections.

- **Parameters:**
  - `secure`: Whether to use a secure L2CAP channel (default: true)
  - `timeout`: Seconds to wait for the server to start (default: 15)
- **Returns:** `Future<int>` - The assigned PSM
- **Platform:** iOS 11.0+, Android 10+ (API 29)

```dart
int psm = await FlutterBlueMax.listenL2capChannel(secure: true);
```

#### `stopL2capServer(int psm)`
Stops an L2CAP server by PSM and closes its accepted channels.

- **Parameters:**
  - `psm`: The PSM of the server to stop
- **Returns:** `Future<void>`

```dart
await FlutterBlueMax.stopL2capServer(psm);
```

### BluetoothDevice

#### `openL2CapChannel(int psm, {bool secure = true, int timeout = 35})`
Opens an L2CAP channel to the connected device.

- **Parameters:**
  - `psm`: Protocol Service Multiplexer to connect to
  - `secure`: Whether to use a secure L2CAP channel (default: true).
    On Android this selects `createL2capChannel()` vs `createInsecureL2capChannel()`;
    on iOS security is controlled by the server's encryption setting.
  - `timeout`: Seconds to wait for the channel to open (default: 35)
- **Returns:** `Future<BluetoothL2capChannel>`
- **Throws:** `FlutterBlueMaxException` if the device is not connected, the open fails, or the timeout elapses
- **Platform:** iOS 11.0+, Android 10+ (API 29)

```dart
BluetoothL2capChannel channel = await device.openL2CapChannel(1234, secure: true);
```

### BluetoothL2capChannel

Encapsulates one L2CAP channel. Returned by `openL2CapChannel()`, or constructed
from an `onL2capConnected` event for server-accepted channels.

#### Properties
- `DeviceIdentifier deviceId` - The device this channel connects to
- `int psm` - The Protocol Service Multiplexer for this channel

#### `write(List<int> data)`
Writes data to the L2CAP channel.

- **Returns:** `Future<void>` - completes once the platform has accepted all bytes
- **Throws:** `FlutterBlueMaxException` on write failure or if the channel is closed

```dart
await channel.write([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello"
```

#### `read()`
Reads data currently buffered for this channel. Returns an empty list when no
data is buffered — it does not wait for data to arrive. Prefer the event
streams for reception.

- **Returns:** `Future<List<int>>` - The received bytes (possibly empty)

```dart
List<int> data = await channel.read();
```

#### `close()`
Closes the L2CAP channel and releases resources. Does not emit an `onClosed` event.

```dart
await channel.close();
```

#### `onL2CapChannelReceived`
Stream of incoming data for this channel only (`Stream<List<int>>`).

#### `onClosed`
Stream that emits when this channel dies — remote close, stream error, or
device disconnect (`Stream<void>`). Not emitted for a local `close()` call; a
single close may be reported more than once in rare races, so cancel the
subscription on the first event if you only care about the transition.

## Event Streams

Global streams on `FlutterBlueMax` (all devices, all PSMs). Match events to
your channels by **device + PSM**, not PSM alone — multiple devices commonly
share the same PSM.

### `FlutterBlueMax.onL2capConnected`
A remote device connected to a server started with `listenL2capChannel`.
Build a `BluetoothL2capChannel` from the event to talk to the client.

The event's `remoteId` is the client's MAC address on Android; on iOS
CoreBluetooth does not expose the connecting central, so the placeholder id
`server` is reported instead. Both platforms accept either id for operations
on server-accepted channels, but data and close events always carry the same
id as this event — so always key channels by the id reported here.

```dart
FlutterBlueMax.onL2capConnected.listen((L2CapChannelConnected evt) {
  final channel = BluetoothL2capChannel(deviceId: evt.remoteId, psm: evt.psm);
});
```

### `FlutterBlueMax.onL2capReceived`
Incoming L2CAP data, for client and server-accepted channels.

```dart
FlutterBlueMax.onL2capReceived.listen((L2CapChannelData data) {
  print('Device: ${data.remoteId}');
  print('PSM: ${data.psm}');
  print('Data: ${data.value}');
});
```

### `FlutterBlueMax.onL2capClosed`
A channel died: the remote closed it, a stream error occurred, or the device
disconnected. Not emitted for a local `close()` call.

```dart
FlutterBlueMax.onL2capClosed.listen((L2CapChannelClosed evt) {
  print('Closed: ${evt.remoteId} / PSM ${evt.psm}');
});
```

## Platform Support

| Platform | Client Support | Server Support | Minimum Version |
|----------|----------------|----------------|------------------|
| **iOS**     | ✅ Full        | ✅ Full        | iOS 11.0         |
| **Android** | ✅ Full        | ✅ Full        | Android 10 (API 29) |
| **Web**     | ❌ Not supported | ❌ Not supported | N/A            |

## Complete Example

```dart
import 'package:flutter_blue_max/flutter_blue_max.dart';

class L2CAPExample {
  int? serverPsm;
  BluetoothL2capChannel? serverChannel; // channel to a connected client
  BluetoothL2capChannel? clientChannel;

  // Start L2CAP server
  Future<void> startServer() async {
    serverPsm = await FlutterBlueMax.listenL2capChannel(secure: true);
    print('L2CAP server started on PSM: $serverPsm');

    FlutterBlueMax.onL2capConnected.listen((evt) {
      if (evt.psm != serverPsm) return;
      serverChannel = BluetoothL2capChannel(deviceId: evt.remoteId, psm: evt.psm);
      print('Client connected: ${evt.remoteId}');
    });

    FlutterBlueMax.onL2capReceived.listen((data) {
      if (data.psm != serverPsm) return;
      print('Server received: ${String.fromCharCodes(data.value)}');
    });

    FlutterBlueMax.onL2capClosed.listen((evt) {
      if (serverChannel != null &&
          evt.remoteId == serverChannel!.deviceId &&
          evt.psm == serverChannel!.psm) {
        print('Client channel closed');
        serverChannel = null;
      }
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

    // React to incoming data and channel death
    clientChannel!.onL2CapChannelReceived.listen((value) {
      print('Client received: ${String.fromCharCodes(value)}');
    });
    clientChannel!.onClosed.first.then((_) {
      print('Channel closed by remote');
      clientChannel = null;
    });

    // Send data
    String message = "Hello from L2CAP client!";
    await clientChannel!.write(message.codeUnits);
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
      serverChannel = null;
    }
  }
}
```

## Error Handling

L2CAP methods follow the same error handling patterns as other flutter_blue_max operations. `openL2CapChannel` and `listenL2capChannel` also throw when their timeout elapses, so a hung platform call cannot block the package-wide operation mutexes forever.

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
2. **Listen to `onClosed` / `onL2capClosed`** — otherwise the only sign of a dead channel is a failing write
3. **Match events by device + PSM**, not PSM alone; key server channels by the id from `onL2capConnected`
4. **Close channels explicitly** to free resources
5. **Stop servers when done** to prevent resource leaks
6. **Prefer the event streams over `read()`** — `read()` only returns already-buffered data
7. **Use secure channels** unless specifically needing insecure connections

## Known iOS CoreBluetooth Issues

The iOS implementation works around several CoreBluetooth defects that Apple has not fixed. Reported to Apple:

- **Closing one L2CAP channel closes a different one.** With two channels open on the same peripheral, closing the second channel tears down the first instead. Reported via Feedback Assistant; Apple DTS confirmed it is "under investigation" (Sep 2025) with no resolution. See [BLE l2cap close not correct](https://developer.apple.com/forums/thread/798454). This is why closed channels are kept alive as *zombies* instead of being released while the connection is up — releasing a `CBL2CAPChannel` triggers the same cascade.
- **Multiple L2CAP channels are unreliable** (`rdar://46227689`, since iOS 12.1): `didOpenL2CAPChannel` can report the wrong PSM for the second channel, and data written to one channel can end up on the other. Never answered by Apple. See [Multiple L2CAP channels on iOS](https://developer.apple.com/forums/thread/111099).

Observed behavior without a public Apple report, worked around in this plugin:

- **No client-side close API.** `CBL2CAPChannel` has no `close`; the only teardown is releasing the object (which triggers the cascade above) or a GATT disconnect.
- **"L2CAP PSM already connected" is a dead end.** Re-opening a PSM that iOS still considers connected fails unrecoverably until a GATT disconnect. The plugin therefore recycles or adopts existing channels instead of re-opening.
- **`openL2CAPChannel:` has no timeout and can fail silently.** If stale channel state exists for the PSM, `didOpenL2CAPChannel` is simply never called — neither success nor error. The plugin tears down all channel state on adapter power-off to avoid leaving such stale state behind.
- **No `didDisconnectPeripheral` on adapter power-off.** Connected peripherals silently vanish, so all per-peripheral cleanup must be triggered from the adapter state change instead.

## Architecture Alignment

L2CAP implementation follows the exact same patterns as flutter_blue_max characteristics and services:

- **Object Creation**: `device.openL2CapChannel()` → returns channel object (like `device.discoverServices()`)
- **Object Operations**: `channel.read()`, `channel.write()` (like `characteristic.read()`)
- **Resource Management**: `channel.close()` for explicit cleanup
- **Error Handling**: Same exception types and patterns
- **Platform Abstraction**: Same underlying platform interface

This ensures L2CAP feels natural and familiar to existing flutter_blue_max developers.
