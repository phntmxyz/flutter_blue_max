import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/workbench/channel_session.dart';
import 'package:flutter_blue_max_example/workbench/payload_codec.dart';

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

  BluetoothAdapterState adapter = BluetoothAdapterState.unknown;
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
  List<ChannelSession> get channels => List.unmodifiable(_channels.values);
  List<BluetoothService> get services => _services[selected?.remoteId] ?? [];
  List<BluetoothDevice> get connectedDevices =>
      _watched.map((id) => BluetoothDevice(remoteId: id)).where((device) => device.isConnected).toList();
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
          _channels.putIfAbsent((event.remoteId, event.psm), () => ChannelSession(channel, incoming: true));
          log('L2CAP accepted ${event.remoteId} / PSM ${event.psm}');
        }
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capReceived.listen((event) {
        final session = _channels[(event.remoteId, event.psm)];
        if (session == null) {
          return;
        }
        session.received += event.value.length;
        session.lastReceived = List.of(event.value);
        log(
          'RX ${event.remoteId} / ${event.psm} · ${event.value.length} B · '
          '${PayloadCodec.hex(event.value.take(64).toList())}',
        );
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capClosed.listen((event) {
        _channels.remove((event.remoteId, event.psm));
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
          log('${nameOf(device)}: ${state.name}');
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
    _update();
  }

  Future<void> scan() => run('scan', () async {
    if (scanning) {
      await FlutterBlueMax.stopScan();
    } else {
      await FlutterBlueMax.startScan(timeout: const Duration(seconds: 15));
    }
  });

  Future<void> connect() => run('connection', () async {
    final device = selected!;
    await FlutterBlueMax.stopScan();
    await device.connect(mtu: null);
    if (_disposed) {
      await device.disconnect();
    }
  });

  Future<void> disconnect() => run('connection', () async {
    await selected!.disconnect();
  });

  Future<void> discover() => run('discover', () async {
    final device = selected!;
    final result = await device.discoverServices();
    if (device.isConnected) {
      _services[device.remoteId] = result;
      log('${result.length} services discovered on ${nameOf(device)}');
    }
  });

  Future<void> readRssi() => run('rssi', () async {
    final device = selected!;
    final value = await device.readRssi();
    if (selected == device) {
      rssi = value;
    }
  });

  Future<void> requestMtu(int value) => run('mtu', () async {
    await selected!.requestMtu(value);
  });

  Future<void> startServer({required bool secure}) => run('server', () async {
    if (serverPsm != null) {
      return;
    }
    _startingServer = true;
    late final int psm;
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
        _channels.remove(session.key);
      }),
    );
  });

  /// Binds an outgoing channel to the inspected peer, never to later device selection.
  Future<void> openChannel(int psm, {required BluetoothDevice device, required bool secure}) => run('open', () async {
    final key = (device.remoteId, psm);
    if (_channels.containsKey(key)) {
      throw StateError('This peer already has a channel on PSM $psm.');
    }
    final channel = await device.openL2CapChannel(psm, secure: secure);
    if (_disposed || !device.isConnected) {
      await channel.close();
      return;
    }
    _channels[key] = ChannelSession(channel, incoming: false);
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

  Future<void> closeChannel(ChannelSession session) => run('channel:${session.key}', () async {
    await session.channel.close();
    _channels.remove(session.key);
  });

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
      error = '$operation: $exception';
      log('ERROR $error');
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
      for (final session in _channels.values.toList()) session.channel.close,
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
