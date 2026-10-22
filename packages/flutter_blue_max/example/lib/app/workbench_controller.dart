import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';

/// Owns the example's Bluetooth session across navigation and device selection.
/// The package remains responsible for platform I/O and operation serialization.
class WorkbenchController extends ChangeNotifier {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _watched = <DeviceIdentifier>{};
  final _services = <DeviceIdentifier, List<BluetoothService>>{};
  final _channels = <(DeviceIdentifier, int), ChannelSession>{};
  final _busy = <String>{};
  final _logs = <String>[];
  bool _disposed = false;
  bool _started = false;
  bool _startingServer = false;

  List<BluetoothDevice> systemDevices = [];
  BluetoothDevice? connectingDevice;
  bool _cancelConnection = false;

  BluetoothAdapterState adapter = BluetoothAdapterState.unknown;

  /// The local Bluetooth name shown alongside nearby devices.
  String? localName;
  List<ScanResult> scanResults = [];
  BluetoothDevice? selected;
  bool scanning = false;
  int? serverPsm;
  String? error;
  String query = '';
  int? rssi;
  int? mtu;

  /// Bounded to keep a long-running diagnostic session from growing indefinitely.
  static const maxLogEntries = 500;

  List<String> get logs => List.unmodifiable(_logs);
  List<ChannelSession> get channels => List.unmodifiable(_channels.values.where((session) => !session.closed));

  /// Closed channels keep their diagnostics available until the device session resets.
  List<ChannelSession> get channelSessions => List.unmodifiable(_channels.values);
  List<BluetoothService> get services => _services[selected?.remoteId] ?? [];
  List<BluetoothDevice> get connectedDevices => FlutterBlueMax.connectedDevices;
  ScanResult? get selectedAdvertisement {
    for (final result in scanResults) {
      if (result.device == selected) {
        return result;
      }
    }
    return null;
  }

  bool get connected => selected?.isConnected ?? false;
  bool get ready => adapter == BluetoothAdapterState.on;
  bool busy(String operation) => _busy.contains(operation);

  /// The current web and Linux backends do not implement L2CAP.
  bool get supportsL2cap =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
        _ => false,
      };

  List<ScanResult> get visibleDevices {
    final search = query.trim().toLowerCase();
    return scanResults.where((result) {
      final searchable =
          '${nameOf(result.device)} ${result.device.remoteId} '
                  '${result.advertisementData.advName} ${result.advertisementData.serviceUuids}'
              .toLowerCase();
      return searchable.contains(search);
    }).toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Advertised names may arrive before the platform resolves a device name.
  String nameOf(BluetoothDevice device) {
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    for (final result in scanResults) {
      if (result.device == device && result.advertisementData.advName.isNotEmpty) {
        return result.advertisementData.advName;
      }
    }
    return 'Unnamed device';
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _subscriptions.add(FlutterBlueMax.logs.listen(log));
    _subscriptions.add(
      FlutterBlueMax.scanResults.listen((results) {
        scanResults = results;
        _update();
      }, onError: _streamError),
    );
    _subscriptions.add(
      FlutterBlueMax.isScanning.listen((value) {
        scanning = value;
        _update();
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capConnected.listen((event) {
        if (event.psm == serverPsm || _startingServer) {
          final channel = BluetoothL2capChannel(deviceId: event.remoteId, psm: event.psm);
          _trackChannel(channel, incoming: true);
          log('L2CAP accepted ${event.remoteId} / PSM ${event.psm}');
        }
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capReceived.listen((event) {
        final session = _channels[(event.remoteId, event.psm)];
        if (session == null || session.closed) {
          return;
        }
        session.received += event.value.length;
        session.recordReceived(event.value, source: 'Stream');
        log(
          'RX ${event.remoteId} / ${event.psm} · ${event.value.length} B · '
          '${PayloadCodec.hex(event.value.take(64).toList())}',
        );
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capClosed.listen((event) {
        _channels[(event.remoteId, event.psm)]?.closed = true;
        log('L2CAP closed ${event.remoteId} / PSM ${event.psm}');
      }),
    );
    await run('initialize', () async {
      await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
      if (_disposed) {
        return;
      }
      _subscriptions.add(
        FlutterBlueMax.adapterState.listen((state) {
          adapter = state;
          if (state == BluetoothAdapterState.on && localName == null) {
            unawaited(_loadLocalName());
          }
          if (state != BluetoothAdapterState.on && state != BluetoothAdapterState.unknown) {
            _channels.clear();
            _services.clear();
            serverPsm = null;
          }
          _update();
        }, onError: _streamError),
      );
    });
  }

  void setQuery(String value) {
    query = value;
    _update();
  }

  Future<void> _loadLocalName() async {
    try {
      localName = (await FlutterBlueMax.adapterName).trim();
    } catch (exception, stackTrace) {
      log('Local device name: $exception');
      debugPrintStack(stackTrace: stackTrace);
    }
    _update();
  }

  void select(BluetoothDevice device) {
    selected = device;
    rssi = null;
    mtu = device.mtuNow;
    if (_watched.add(device.remoteId)) {
      _subscriptions.add(
        device.onServicesReset.listen((_) {
          _services.remove(device.remoteId);
          log('Services changed on ${nameOf(device)}. Discover services again.');
        }),
      );
      _subscriptions.add(
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _services.remove(device.remoteId);
            _channels.removeWhere((key, _) => key.$1 == device.remoteId);
          }
          log(
            '${nameOf(device)}: ${state.name}'
            '${state == BluetoothConnectionState.disconnected ? ' · ${device.disconnectReason}' : ''}',
          );
          if (state == BluetoothConnectionState.connected && selected == device) {
            unawaited(readRssi());
          }
        }),
      );
      _subscriptions.add(
        device.mtu.listen((value) {
          if (selected == device) {
            mtu = value;
            _update();
          }
        }),
      );
    }
    if (device.isConnected) {
      unawaited(readRssi());
    }
    _update();
  }

  Future<void> scan() => run('scan', () async {
    if (scanning) {
      await FlutterBlueMax.stopScan();
    } else {
      if (!kIsWeb) {
        await refreshSystemDevices();
      }
      await FlutterBlueMax.startScan(
        timeout: const Duration(seconds: 15),
        // Preserve the original example's browser service permissions.
        webOptionalServices: [Guid('180f'), Guid('180a'), Guid('1800'), Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')],
      );
    }
  });

  Future<void> refreshScan() async {
    if (!scanning && ready) {
      await scan();
    }
  }

  Future<void> refreshSystemDevices() => run('systemDevices', () async {
    systemDevices = await FlutterBlueMax.systemDevices([Guid('180f')]);
  });

  Future<void> connect() => run('connection', () async {
    final device = selected!;
    connectingDevice = device;
    _cancelConnection = false;
    _update();
    try {
      await FlutterBlueMax.stopScan();
      if (_cancelConnection) {
        return;
      }
      await device.connect(mtu: null);
      if (_disposed || _cancelConnection) {
        await device.disconnect(queue: false);
      }
    } on FlutterBlueMaxException catch (error, stackTrace) {
      if (!_cancelConnection) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    } finally {
      connectingDevice = null;
    }
  });

  /// Cancellation bypasses both the sample's connection lock and the plugin queue.
  Future<void> cancelConnect() => run('cancelConnection', () async {
    final device = connectingDevice;
    if (device == null) {
      return;
    }
    _cancelConnection = true;
    await device.disconnect(queue: false);
  });

  Future<void> disconnect() => run('connection', () async {
    await selected!.disconnect();
  });

  Future<void> turnOn() => run('adapter', () async {
    await FlutterBlueMax.turnOn();
  });

  Future<void> discover() => run('discover', () async {
    final device = selected!;
    final result = await device.discoverServices();
    if (device.isConnected) {
      _services[device.remoteId] = result;
      log('${result.length} services discovered on ${nameOf(device)}');
    }
  });

  Future<void> readRssi() async {
    if (kIsWeb) {
      return;
    }
    final device = selected!;
    await run('rssi:${device.remoteId}', () async {
      final value = await device.readRssi();
      if (selected == device) {
        rssi = value;
      }
    });
  }

  Future<void> requestMtu(int value) => run('mtu', () async {
    await selected!.requestMtu(value);
  });

  Future<void> startServer({required bool secure}) => run('server', () async {
    if (!supportsL2cap) {
      throw UnsupportedError('L2CAP is not available on this platform.');
    }
    if (serverPsm != null) {
      return;
    }
    _startingServer = true;
    final int psm;
    try {
      psm = await FlutterBlueMax.listenL2capChannel(secure: secure);
    } finally {
      _startingServer = false;
    }
    if (_disposed || !ready) {
      await FlutterBlueMax.stopL2capServer(psm);
      return;
    }
    serverPsm = psm;
    log('Server listening on PSM $psm (${secure ? 'secure' : 'insecure'})');
  });

  Future<void> stopServer() => run('server', () async {
    final psm = serverPsm;
    if (psm == null) {
      return;
    }
    await FlutterBlueMax.stopL2capServer(psm);
    serverPsm = null;
    // Unpublishing on Apple stops accepting peers but leaves accepted streams open.
    // Close them explicitly, retaining any failed close in the UI for retry.
    final accepted = channels.where((session) => session.incoming && session.channel.psm == psm).toList();
    await Future.wait(
      accepted.map((session) async {
        await session.channel.close();
        session.closed = true;
      }),
    );
  });

  /// Binds an outgoing channel to the inspected peer, never to later device selection.
  Future<void> openChannel(int psm, {required BluetoothDevice device, required bool secure}) => run('open', () async {
    if (!supportsL2cap) {
      throw UnsupportedError('L2CAP is not available on this platform.');
    }
    final key = (device.remoteId, psm);
    if (_channels[key]?.closed == false) {
      throw StateError('This peer already has a channel on PSM $psm.');
    }
    final channel = await () async {
      try {
        return await device.openL2CapChannel(psm, secure: secure);
      } catch (error, stackTrace) {
        if (_disposed || !ready || _isUnsupported(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        log('L2CAP open failed; retrying once: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!device.isConnected) {
          await device.connect(mtu: null);
        }
        return await device.openL2CapChannel(psm, secure: secure);
      }
    }();
    if (_disposed || !device.isConnected) {
      await channel.close();
      return;
    }
    _trackChannel(channel, incoming: false);
    log('L2CAP opened ${device.remoteId} / PSM $psm');
  });

  Future<void> send(ChannelSession session, List<int> bytes) => run('channel:${session.key}', () async {
    await session.channel.write(bytes);
    session.transmitted += bytes.length;
    log(
      'TX ${session.channel.deviceId} / ${session.channel.psm} · ${bytes.length} B · '
      '${PayloadCodec.hex(bytes.take(64).toList())}',
    );
  });

  /// Explicit reads drain the native buffer; streamed bytes are not counted twice.
  Future<void> readChannel(ChannelSession session) => run('channel:${session.key}', () async {
    final bytes = await session.channel.read();
    session.recordReceived(bytes, source: 'Buffer read');
    log('Buffer read ${session.channel.deviceId} / ${session.channel.psm}: ${bytes.length} B');
  });

  /// Patterned traffic exposes truncation; concurrent writes exercise native backpressure.
  Future<void> sendTestTraffic(ChannelSession session, {required int size, required int count}) =>
      run('channel:${session.key}', () async {
        if (size <= 0 || count <= 0) {
          throw const FormatException('Payload size and write count must be positive.');
        }
        final payload = List<int>.generate(size, (i) => i & 0xff);
        var successes = 0;
        await Future.wait(
          List.generate(count, (_) async {
            await session.channel.write(payload);
            session.transmitted += payload.length;
            successes++;
          }),
        ).whenComplete(() {
          log(
            'Test traffic ${session.channel.deviceId} / ${session.channel.psm}: '
            '$successes/$count writes of $size B completed',
          );
        });
      });

  Future<void> closeChannel(ChannelSession session) => run('channel:${session.key}', () async {
    await session.channel.close();
    session.closed = true;
  });

  void _trackChannel(BluetoothL2capChannel channel, {required bool incoming}) {
    final session = _channels.putIfAbsent((
      channel.deviceId,
      channel.psm,
    ), () => ChannelSession(channel, incoming: incoming));
    session.channel = channel;
    session.incoming = incoming;
    session.closed = false;
  }

  /// Reports errors once and prevents duplicate submissions of the same action.
  Future<void> run(String operation, Future<void> Function() action) async {
    if (_disposed || !_busy.add(operation)) {
      return;
    }
    error = null;
    _update();
    try {
      await action();
    } catch (exception, stackTrace) {
      if (_isUnsupported(exception)) {
        error = 'This operation is not supported on this device.';
      } else {
        error = '$operation: $exception';
      }
      log('ERROR $operation: $exception');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _busy.remove(operation);
      _update();
    }
  }

  void dismissError() {
    error = null;
    _update();
  }

  void clearLogs() {
    _logs.clear();
    _update();
  }

  void log(String message) {
    if (_disposed) {
      return;
    }
    _logs.add('${DateTime.now().toIso8601String()}  $message');
    if (_logs.length > maxLogEntries) {
      _logs.removeRange(0, _logs.length - maxLogEntries);
    }
    _update();
  }

  void _streamError(Object exception, StackTrace stackTrace) {
    error = exception.toString();
    log('ERROR $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  void _update() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    // Navigation never disposes this controller; shutdown does. Native hot-restart
    // cleanup is still the fallback when the Dart isolate is terminated abruptly.
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    final psm = serverPsm;
    final cleanup = <Future<void> Function()>[
      if (scanning) FlutterBlueMax.stopScan,
      for (final session in channels) session.channel.close,
      if (psm != null) () => FlutterBlueMax.stopL2capServer(psm),
      for (final id in _watched) () => BluetoothDevice(remoteId: id).disconnect(),
    ];
    for (final action in cleanup) {
      try {
        await action();
      } catch (exception, stackTrace) {
        debugPrint('Bluetooth cleanup: $exception');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}

// Match typed failures and the native Android capability error, not arbitrary
// error text: permission and connection failures must remain retryable.
bool _isUnsupported(Object exception) {
  if (exception is UnsupportedError || exception is UnimplementedError) {
    return true;
  }
  if (exception is PlatformException) {
    return exception.code == 'platform_not_supported';
  }
  return exception is FlutterBlueMaxException &&
      exception.platform == ErrorPlatform.fbp &&
      (exception.code == FbpErrorCode.androidOnly.index || exception.code == FbpErrorCode.applePlatformOnly.index);
}
