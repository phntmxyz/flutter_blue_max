import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_tracker.dart';
import 'package:flutter_blue_max_example/advertisements/parser_library.dart';
import 'package:flutter_blue_max_example/gatt/catalog_import_result.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog_library.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// Owns the example's Bluetooth session across navigation and device selection.
/// The package remains responsible for platform I/O and operation serialization.
class WorkbenchController({
  /// Writes a stored list. Tests replace it to delay or fail a save.
  final Future<void> Function(String key, List<Object?> items, {List<Object?> unreadable}) saveList = saveStoredList,
}) extends ChangeNotifier {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _watched = <DeviceIdentifier>{};
  final _services = <DeviceIdentifier, List<BluetoothService>>{};
  final _channels = <(DeviceIdentifier, int), ChannelSession>{};
  final _busy = <Operation>{};

  /// Characteristics subscribed on web per peer, where no CCCD event reports it; cleared when the link drops.
  final _webSubscriptions = <DeviceIdentifier, Set<Operation>>{};
  final _logs = <String>[];
  late final parserLibrary = ParserLibrary(write: saveList, onProblem: _libraryProblem)..addListener(_update);
  late final catalogLibrary = GattCatalogLibrary(write: saveList, onProblem: _libraryProblem)..addListener(_update);

  /// Counts user-requested disconnects per peer so a pending channel open can
  /// tell a transient drop from an intentional disconnect.
  final _disconnectRequests = <DeviceIdentifier, int>{};
  bool _disposed = false;
  bool _started = false;
  bool _startingServer = false;

  /// Set by a tracking scan and cleared by the next regular scan.
  bool _trackingScan = false;

  List<BluetoothDevice> systemDevices = [];
  BluetoothDevice? connectingDevice;
  bool _cancelConnection = false;

  BluetoothAdapterState adapter = BluetoothAdapterState.unknown;

  /// The local Bluetooth name shown alongside nearby devices.
  String? localName;
  List<ScanResult> scanResults = [];

  /// The most recent tracking session, kept after the scan stops for inspection.
  AdvertisementTracker? advertisementTracker;
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

  /// Immutable snapshots for panel selectors. Copy mutable collections so a prior selection cannot change in place.
  List<Object?> get deviceState => [
    adapter,
    localName,
    List.of(scanResults),
    List.of(systemDevices),
    connectingDevice,
    selected,
    connected,
    scanning,
    tracking,
    advertisementTracker?.count,
    query,
    rssi,
    mtu,
    Map.of(_services),
    parserLibrary.items,
    catalogLibrary.items,
    _busy.where((o) => o != Operation.server && !_incomingOperation(o)).toList(),
    _channelState(incoming: false),
  ];

  /// The server does not observe discovery, RSSI, GATT or activity changes.
  List<Object?> get serverState => [
    adapter,
    serverPsm,
    _busy.where((o) => o == Operation.server || _incomingOperation(o)).toList(),
    _channelState(incoming: true),
  ];

  bool _incomingOperation(Operation operation) =>
      _channels.values.any((s) => s.incoming && operation == Operation.channel(s));

  List<Object?> _channelState({required bool incoming}) => [
    for (final s in _channels.values)
      if (s.incoming == incoming)
        [s.channel, s.closed, s.transmitted, s.received, List.of(s.lastReceived), List.of(s.history)],
  ];

  /// Global parsers, saved across launches; [parsersFor] narrows them to one peer.
  List<AdvertisementParser> get parsers => parserLibrary.items;
  List<AdvertisementParser> parsersFor(DeviceIdentifier remoteId) =>
      parserLibrary.items.where((parser) => parser.appliesTo(remoteId)).toList();

  /// The user's own GATT catalog services, saved across launches.
  List<KnownService> get catalog => catalogLibrary.items;

  /// The user's own entries replace built-in ones with the same UUID.
  KnownService? knownService(Guid uuid) =>
      catalogLibrary.items.where((s) => s.uuid == uuid).firstOrNull ?? builtInService(uuid);

  List<ChannelSession> get channels => List.unmodifiable(_channels.values.where((s) => !s.closed));

  /// Closed channels keep their diagnostics available until the device session resets.
  List<ChannelSession> get channelSessions => List.unmodifiable(_channels.values);
  List<BluetoothService> get services => _services[selected?.remoteId] ?? [];
  List<BluetoothDevice> get connectedDevices => FlutterBlueMax.connectedDevices;
  ScanResult? get selectedAdvertisement => scanResults.where((r) => r.device == selected).firstOrNull;

  bool get connected => selected?.isConnected ?? false;
  bool get tracking => _trackingScan && scanning;
  bool get ready => adapter == BluetoothAdapterState.on;

  /// Matches the typed operation passed to [run], including any device/channel scope.
  bool busy(Operation operation) => _busy.contains(operation);

  /// Whether this workbench subscribed to [c] on web, which reports no subscription state itself.
  bool subscribedOnWeb(BluetoothCharacteristic c) =>
      _webSubscriptions[c.remoteId]?.contains(Operation.characteristic(c)) ?? false;

  void setSubscribedOnWeb(BluetoothCharacteristic c, {required bool subscribed}) {
    final subscriptions = _webSubscriptions.putIfAbsent(c.remoteId, () => {});
    if (subscribed) {
      subscriptions.add(Operation.characteristic(c));
    } else {
      subscriptions.remove(Operation.characteristic(c));
    }
  }

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
    }).toList();
  }

  /// Advertised names may arrive before the platform resolves a device name.
  String nameOf(BluetoothDevice device) {
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    final advertised = scanResults
        .where((r) => r.device == device && r.advertisementData.advName.isNotEmpty)
        .firstOrNull;
    return advertised?.advertisementData.advName ?? 'Unnamed device';
  }

  /// Starts once, subscribing to plugin events and loading the saved parser/catalog libraries.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    final libraries = Future.wait([parserLibrary.load(), catalogLibrary.load()]);
    _subscriptions.add(FlutterBlueMax.logs.listen(log));
    _subscriptions.add(
      FlutterBlueMax.scanResults.listen((r) {
        final tracker = _trackingScan ? advertisementTracker : null;
        if (tracker == null) {
          scanResults = r;
        } else {
          // A tracking scan delivers single advertisements; keep the rest of the device list.
          for (final result in r) {
            if (result.device.remoteId == tracker.remoteId) {
              tracker.record(result);
            }
            // Replace in place so the device keeps its position in the list.
            scanResults = [
              ...scanResults.map((known) => known == result ? result : known),
              if (!scanResults.contains(result)) result,
            ];
          }
        }
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
        } else {
          unawaited(_closeUnownedChannel(BluetoothL2capChannel(deviceId: event.remoteId, psm: event.psm)));
        }
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capReceived.listen((event) {
        final session = _channels[(event.remoteId, event.psm)];
        if (session == null || session.closed) {
          return;
        }
        session.onStreamed(event.value);
        log(
          'RX ${event.remoteId} / ${event.psm} · ${event.value.length} B · '
          '${PayloadCodec.hex(event.value.take(64).toList())}',
        );
      }),
    );
    _subscriptions.add(
      FlutterBlueMax.onL2capClosed.listen((event) {
        _channels[(event.remoteId, event.psm)]?.markClosed();
        log('L2CAP closed ${event.remoteId} / PSM ${event.psm}');
      }),
    );
    await run(Operation.initialize, () async {
      await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
    });
    // A failed log level (e.g. Linux without bluetoothd) is reported above, but
    // must not leave the app waiting for an adapter state it never subscribed to.
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
          for (final session in _channels.values) {
            session.markClosed();
          }
          _services.clear();
          serverPsm = null;
        }
        _update();
      }, onError: _streamError),
    );
    await libraries;
    _update();
  }

  void _libraryProblem(LibraryProblem problem) {
    error = problem.message;
    log(problem.activity);
    if (problem.stackTrace != null) {
      developer.log(problem.activity, name: 'workbench', error: problem.error, stackTrace: problem.stackTrace);
    }
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
      developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    }
    _update();
  }

  /// Watches connection, MTU and service-reset streams once per peer until this controller is disposed.
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
      // The stream replays a cached state on listen, which is `disconnected` for
      // peers never connected over GATT. Only a real link loss ends the session.
      var wasConnected = false;
      _subscriptions.add(
        device.connectionState.listen((state) {
          final lostConnection = wasConnected && state == BluetoothConnectionState.disconnected;
          wasConnected = state == BluetoothConnectionState.connected;
          if (lostConnection) {
            _services.remove(device.remoteId);
            _webSubscriptions.remove(device.remoteId);
            _closeOutgoingChannels(device.remoteId);
          }
          log(
            '${nameOf(device)}: ${state.name}'
            '${state == BluetoothConnectionState.disconnected ? ' · ${device.disconnectReason}' : ''}',
          );
          if (state == BluetoothConnectionState.connected && selected == device) {
            unawaited(_readRssiAutomatically(device));
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
      unawaited(_readRssiAutomatically(device));
    }
    _update();
  }

  /// Toggles scanning: a running scan is stopped rather than restarted.
  Future<void> scan() => run(Operation.scan, () async {
    if (scanning) {
      await FlutterBlueMax.stopScan();
    } else {
      if (!kIsWeb) {
        await refreshSystemDevices();
      }
      if (_disposed) {
        return;
      }
      _trackingScan = false;
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

  /// Reports every advertisement of one peer until stopped, replacing any running scan.
  Future<void> trackAdvertisements(BluetoothDevice device) => run(Operation.scan, () async {
    if (scanning) {
      await FlutterBlueMax.stopScan();
    }
    if (_disposed) {
      return;
    }
    advertisementTracker = AdvertisementTracker(device.remoteId);
    _trackingScan = true;
    await FlutterBlueMax.startScan(withRemoteIds: [device.remoteId.str], continuousUpdates: true, oneByOne: true);
    log('Tracking advertisements of ${nameOf(device)}');
  });

  Future<void> stopTracking() => run(Operation.scan, () async {
    if (tracking) {
      await FlutterBlueMax.stopScan();
    }
  });

  Future<void> refreshSystemDevices() => run(Operation.systemDevices, () async {
    systemDevices = await FlutterBlueMax.systemDevices([Guid('180f')]);
  });

  Future<void> connect() => run(Operation.connection, () async {
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
  Future<void> cancelConnect() => run(Operation.cancelConnection, () async {
    final device = connectingDevice;
    if (device == null) {
      return;
    }
    _cancelConnection = true;
    await device.disconnect(queue: false);
  });

  Future<void> disconnect() => run(Operation.connection, () async {
    final device = selected!;
    _disconnectRequests.update(device.remoteId, (count) => count + 1, ifAbsent: () => 1);
    await device.disconnect();
  });

  Future<void> turnOn() => run(Operation.adapter, () async {
    await FlutterBlueMax.turnOn();
  });

  /// Discovers services and also reads their Characteristic User Description descriptors.
  Future<void> discover() => run(Operation.discover, () async {
    final device = selected!;
    final result = await device.discoverServices();
    if (device.isConnected) {
      _services[device.remoteId] = result;
      log('${result.length} services discovered on ${nameOf(device)}');
      _update();
      await _readUserDescriptions(device, result);
    }
  });

  /// Labels characteristics the GATT catalog does not know. A failed read only loses that label.
  Future<void> _readUserDescriptions(BluetoothDevice device, List<BluetoothService> services) async {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        for (final descriptor in characteristic.descriptors) {
          if (descriptor.uuid != userDescriptionUuid) {
            continue;
          }
          if (!device.isConnected) {
            return;
          }
          try {
            await descriptor.read();
          } catch (exception, stackTrace) {
            log('User description of ${characteristic.uuid}: $exception');
            developer.log('Read user description failed', name: 'workbench', error: exception, stackTrace: stackTrace);
          }
          _update();
        }
      }
    }
  }

  Future<void> _readRssiAutomatically(BluetoothDevice device) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _refreshRssi(device);
    } catch (exception, stackTrace) {
      log('Automatic RSSI read failed: $exception');
      developer.log('Automatic RSSI read failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    }
  }

  Future<void> _refreshRssi(BluetoothDevice device) async {
    final value = await device.readRssi();
    if (selected == device) {
      rssi = value;
      _update();
    }
  }

  Future<void> readRssi() async {
    if (kIsWeb) {
      return;
    }
    final device = selected!;
    await run(Operation.rssi(device), () => _refreshRssi(device));
  }

  Future<void> requestMtu(int value) => run(Operation.mtu, () async {
    await selected!.requestMtu(value);
  });

  Future<void> startServer({required bool secure}) => run(Operation.server, () async {
    if (!supportsL2cap) {
      throw const _Unsupported('L2CAP is not available on this platform.');
    }
    if (serverPsm != null) {
      return;
    }
    _startingServer = true;
    final int psm;
    try {
      psm = await FlutterBlueMax.listenL2capChannel(secure: secure).orUnsupported();
    } catch (_) {
      await Future.wait(channels.where((s) => s.incoming).map((s) => _closeUnownedChannel(s.channel)));
      rethrow;
    } finally {
      _startingServer = false;
    }
    if (_disposed || !ready) {
      await FlutterBlueMax.stopL2capServer(psm);
      return;
    }
    serverPsm = psm;
    await Future.wait(
      channels.where((s) => s.incoming && s.channel.psm != psm).map((s) => _closeUnownedChannel(s.channel)),
    );
    log('Server listening on PSM $psm (${secure ? 'secure' : 'insecure'})');
  });

  Future<void> _closeUnownedChannel(BluetoothL2capChannel channel) async {
    try {
      await channel.close();
      _channels[(channel.deviceId, channel.psm)]?.markClosed();
      _update();
    } catch (exception, stackTrace) {
      if (_disposed) {
        return;
      }
      // Keep a failed native close reachable through the card's Close action.
      _trackChannel(channel, incoming: true);
      error = 'Closing late L2CAP accept: $exception';
      log('ERROR $error');
      developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    }
  }

  Future<void> stopServer() => run(Operation.server, () async {
    final psm = serverPsm;
    if (psm == null) {
      return;
    }
    await FlutterBlueMax.stopL2capServer(psm);
    serverPsm = null;
    // Unpublishing on Apple stops accepting peers but leaves accepted streams open.
    // Close them explicitly, retaining any failed close in the UI for retry.
    final accepted = channels.where((s) => s.incoming && s.channel.psm == psm).toList();
    await Future.wait(
      accepted.map((s) async {
        await s.channel.close();
        s.markClosed();
      }),
    );
  });

  /// Binds an outgoing channel to the inspected peer, never to later device selection.
  Future<void> openChannel(int psm, {required BluetoothDevice device, required bool secure}) =>
      run(Operation.open, () async {
        if (!supportsL2cap) {
          throw const _Unsupported('L2CAP is not available on this platform.');
        }
        final key = (device.remoteId, psm);
        if (_channels[key]?.closed == false) {
          throw StateError('This peer already has a channel on PSM $psm.');
        }
        final disconnects = _disconnectRequests[device.remoteId] ?? 0;
        final channel = await () async {
          try {
            return await device.openL2CapChannel(psm, secure: secure).orUnsupported();
          } catch (error, stackTrace) {
            // A secure handshake can drop the link transiently; a disconnect the
            // user requested meanwhile must not be undone by the retry.
            final userDisconnected = (_disconnectRequests[device.remoteId] ?? 0) != disconnects;
            if (_disposed || !ready || userDisconnected || _isUnsupported(error)) {
              Error.throwWithStackTrace(error, stackTrace);
            }
            log('L2CAP open failed; retrying once: $error');
            developer.log('L2CAP open failed; retrying', name: 'workbench', error: error, stackTrace: stackTrace);
            if (!device.isConnected) {
              await device.connect(mtu: null);
            }
            return await device.openL2CapChannel(psm, secure: secure).orUnsupported();
          }
        }();
        if (_disposed || !device.isConnected) {
          await channel.close();
          return;
        }
        _trackChannel(channel, incoming: false);
        log('L2CAP opened ${device.remoteId} / PSM $psm');
      });

  Future<void> send(ChannelSession session, List<int> bytes) => run(Operation.channel(session), () async {
    await session.channel.write(bytes);
    session.onTransmitted(bytes);
    log(
      'TX ${session.channel.deviceId} / ${session.channel.psm} · ${bytes.length} B · '
      '${PayloadCodec.hex(bytes.take(64).toList())}',
    );
  });

  /// Explicit reads drain the native buffer; streamed bytes are not counted twice.
  /// An empty read is only logged, so it neither hides the last chunk nor evicts history.
  Future<void> readChannel(ChannelSession session) => run(Operation.channel(session), () async {
    final bytes = await session.channel.read();
    session.onBufferRead(bytes);
    log('Buffer read ${session.channel.deviceId} / ${session.channel.psm}: ${bytes.length} B');
  });

  /// Patterned traffic exposes truncation; concurrent writes exercise native backpressure.
  Future<void> sendTestTraffic(ChannelSession session, {required int size, required int count}) =>
      run(Operation.channel(session), () async {
        if (size <= 0 || count <= 0) {
          throw const FormatException('Payload size and write count must be positive.');
        }
        final payload = List<int>.generate(size, (i) => i & 0xff);
        var successes = 0;
        await Future.wait(
          List.generate(count, (_) async {
            await session.channel.write(payload);
            session.onTransmitted(payload);
            successes++;
            _update();
          }),
        ).whenComplete(() {
          log(
            'Test traffic ${session.channel.deviceId} / ${session.channel.psm}: '
            '$successes/$count writes of $size B completed',
          );
        });
      });

  Future<void> closeChannel(ChannelSession session) => run(Operation.channel(session), () async {
    await session.channel.close();
    session.markClosed();
  });

  /// Outgoing channels belong to the GATT session that opened them. Incoming
  /// channels belong to the local server and stay untouched.
  void _closeOutgoingChannels(DeviceIdentifier remoteId) {
    final outgoing = channels.where((s) => !s.incoming && s.channel.deviceId == remoteId);
    for (final session in outgoing.toList()) {
      session.markClosed();
      unawaited(
        session.channel.close().catchError((Object exception, StackTrace stackTrace) {
          log('L2CAP close after link loss ${session.channel.deviceId} / ${session.channel.psm}: $exception');
          developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
        }),
      );
    }
  }

  void _trackChannel(BluetoothL2capChannel channel, {required bool incoming}) {
    final session = _channels.putIfAbsent((
      channel.deviceId,
      channel.psm,
    ), () => ChannelSession(channel, incoming: incoming));
    session.reopen(channel, incoming: incoming);
  }

  /// Reports errors once and prevents duplicate submissions of the same action.
  Future<void> run(Operation operation, Future<void> Function() action) async {
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
        error = '${operation.label}: $exception';
      }
      log('ERROR ${operation.label}: $exception');
      developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    } finally {
      _busy.remove(operation);
      _update();
    }
  }

  /// Replaces [previous] in place so the display order stays stable while editing.
  Future<void> saveParser(AdvertisementParser parser, {AdvertisementParser? previous}) =>
      parserLibrary.saveParser(parser, previous: previous);
  Future<void> removeParser(AdvertisementParser parser) => parserLibrary.removeParser(parser);
  Future<int> addParsers(List<AdvertisementParser> parsers) => parserLibrary.addParsers(parsers);
  Future<void> resetParsers() => parserLibrary.resetParsers();
  Future<void> saveCatalogService(KnownService service, {KnownService? previous}) =>
      catalogLibrary.saveCatalogService(service, previous: previous);
  Future<void> removeCatalogService(KnownService service) => catalogLibrary.removeCatalogService(service);
  KnownService? catalogServiceReplacedBy(KnownService service) => catalogLibrary.catalogServiceReplacedBy(service);
  Future<CatalogImportResult> addCatalogServices(List<KnownService> services) =>
      catalogLibrary.addCatalogServices(services);
  Future<void> resetCatalog() => catalogLibrary.resetCatalog();

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
    _logs.add('${clock.now().toIso8601String()}  $message');
    if (_logs.length > maxLogEntries) {
      _logs.removeRange(0, _logs.length - maxLogEntries);
    }
    _update();
  }

  void _streamError(Object exception, StackTrace stackTrace) {
    error = exception.toString();
    log('ERROR $error');
    developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
  }

  void _update() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    parserLibrary.dispose();
    catalogLibrary.dispose();
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
        developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
      }
    }
  }
}

/// Identifies an operation for [WorkbenchController.run] and [WorkbenchController.busy].
/// Operations with a [scope], such as one channel, run independently of each other.
class const Operation._(
  /// Prefixes the error the operation reports.
  final String label, [
  final Object? scope,
]) {
  static const initialize = Operation._('Initialize');
  static const scan = Operation._('Scan');
  static const systemDevices = Operation._('System devices');
  static const connection = Operation._('Connection');
  static const cancelConnection = Operation._('Cancel connection');
  static const adapter = Operation._('Turn on Bluetooth');
  static const discover = Operation._('Service discovery');
  static const bond = Operation._('Bond');
  static const mtu = Operation._('MTU request');
  static const server = Operation._('L2CAP server');
  static const open = Operation._('Open L2CAP channel');

  new rssi(BluetoothDevice device) : this._('Read RSSI', device.remoteId);
  new channel(ChannelSession session) : this._('L2CAP channel', session.key);
  new characteristic(BluetoothCharacteristic c)
    : this._('Characteristic ${c.uuid}', (c.remoteId, c.serviceUuid, c.uuid, c.instanceId));
  new descriptor(BluetoothDescriptor d)
    : this._('Descriptor ${d.uuid}', (d.remoteId, d.serviceUuid, d.characteristicUuid, d.uuid, d.instanceId));

  @override
  bool operator ==(Object other) => other is Operation && other.label == label && other.scope == scope;

  @override
  int get hashCode => Object.hash(label, scope);
}

/// A capability the platform lacks, as opposed to a failure of the operation.
class const _Unsupported(final Object cause) implements Exception {
  @override
  String toString() => '$cause';
}

extension<T> on Future<T> {
  /// The platform interface throws [UnimplementedError], an [UnsupportedError], for features a platform lacks.
  /// Elsewhere in an action these errors are bugs, so only plugin calls are marked.
  Future<T> orUnsupported() {
    return onError<UnsupportedError>((error, stackTrace) => Error.throwWithStackTrace(_Unsupported(error), stackTrace));
  }
}

// Match typed failures and the native Android capability error, not arbitrary
// error text: permission and connection failures must remain retryable.
bool _isUnsupported(Object exception) {
  if (exception is _Unsupported) {
    return true;
  }
  if (exception is PlatformException) {
    return exception.code == 'platform_not_supported';
  }
  return exception is FlutterBlueMaxException &&
      exception.platform == ErrorPlatform.fbp &&
      (exception.code == FbpErrorCode.androidOnly.index || exception.code == FbpErrorCode.applePlatformOnly.index);
}
