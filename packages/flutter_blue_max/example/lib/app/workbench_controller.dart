import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_tracker.dart';
import 'package:flutter_blue_max_example/advertisements/parser_library.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog_library.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// Owns the example's Bluetooth session across navigation and device selection.
/// The package remains responsible for platform I/O and operation serialization.
class WorkbenchController({
  /// Writes a stored list.
  /// Tests replace it to delay or fail a save.
  final Future<void> Function(String key, List<Object?> items, {List<Object?> unreadable}) saveList = saveStoredList,
}) extends ChangeNotifier {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _peerSubscriptions = <DeviceIdentifier, List<StreamSubscription<dynamic>>>{};
  DeviceIdentifier? _openingPeer;
  final _services = <DeviceIdentifier, List<BluetoothService>>{};
  final _serviceGenerations = <DeviceIdentifier, int>{};
  final _connectionGenerations = <DeviceIdentifier, int>{};
  final _characteristicValues = <DeviceIdentifier, Map<Operation, _CharacteristicValue>>{};
  // Native callbacks still identify channels by peer and PSM.
  final _channels = <(DeviceIdentifier, int), ChannelSession>{};
  final _channelSessions = <(DeviceIdentifier, int, bool), ChannelSession>{};
  StreamSubscription<L2CapChannelConnected>? _acceptSubscription;
  Future<void>? _serverWork;
  Future<void>? _scanStartDone;
  Future<void>? _shutdownWork;
  final _busy = <Operation>{};

  /// Characteristics subscribed on web per peer, where no CCCD event reports it; cleared when the link drops.
  final _webSubscriptions = <DeviceIdentifier, Set<Operation>>{};
  final _activity = ValueNotifier<List<ActivityEntry>>(const []);
  late final parserLibrary = ParserLibrary(write: saveList, onProblem: _libraryProblem)..addListener(_update);
  late final catalogLibrary = GattCatalogLibrary(write: saveList, onProblem: _libraryProblem)..addListener(_update);

  /// Counts user-requested disconnects per peer so a pending open can distinguish a link drop from an intentional disconnect.
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
  int _scanRevision = 0;

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

  List<String> get logs => List.unmodifiable(_activity.value.map((entry) => entry.text));
  ValueListenable<List<ActivityEntry>> get activity => _activity;

  /// Scan results compare by peer ID, so the revision also captures changes to a peer's data.
  List<Object?> get discoveryState => [
    adapter,
    localName,
    _scanRevision,
    List.of(systemDevices),
    List.of(connectedDevices),
    selected,
    scanning,
    query,
    busy(Operation.scan),
  ];

  /// Snapshot outgoing traffic and operations for the inspected peer only.
  List<Object?> outgoingChannelState(DeviceIdentifier peer) => [
    for (final session in _channelSessions.values)
      if (!session.incoming && session.channel.deviceId == peer)
        [
          session.channel,
          session.closed,
          session.transmitted,
          session.received,
          session.history,
          busy(Operation.channel(session)),
        ],
  ];

  /// The server does not observe discovery, RSSI, GATT or activity changes.
  List<Object?> get serverState => [
    adapter,
    serverPsm,
    _busy.where((o) => o == Operation.server || _incomingOperation(o)).toList(),
    _incomingChannelState,
  ];

  bool _incomingOperation(Operation operation) =>
      _channelSessions.values.any((s) => s.incoming && operation == Operation.channel(s));

  List<Object?> get _incomingChannelState => [
    for (final s in _channelSessions.values)
      if (s.incoming) [s.channel, s.closed, s.transmitted, s.received, s.history],
  ];

  /// Global parsers, saved across launches; [parsersFor] narrows them to one peer.
  List<AdvertisementParser> get parsers => parserLibrary.parsers;
  List<AdvertisementParser> parsersFor(DeviceIdentifier remoteId) =>
      parserLibrary.parsers.where((parser) => parser.appliesTo(remoteId)).toList();

  /// The user's own GATT catalog services, saved across launches.
  List<KnownService> get catalog => catalogLibrary.catalog;

  /// The user's own entries replace built-in ones with the same UUID.
  KnownService? knownService(Guid uuid) =>
      catalogLibrary.catalog.where((s) => s.uuid == uuid).firstOrNull ?? builtInService(uuid);

  List<ChannelSession> get channels => List.unmodifiable(_channels.values.where((s) => !s.closed));

  /// Closed channels keep their diagnostics available until the device session resets.
  List<ChannelSession> get channelSessions => List.unmodifiable(_channelSessions.values);
  List<BluetoothService> get services => _services[selected?.remoteId] ?? [];
  List<BluetoothDevice> get connectedDevices => FlutterBlueMax.connectedDevices;
  ScanResult? get selectedAdvertisement => scanResults.where((r) => r.device == selected).firstOrNull;

  bool get connected => selected?.isConnected ?? false;
  bool get tracking => _trackingScan && scanning;
  bool get ready => adapter == BluetoothAdapterState.on;

  /// Matches the typed operation passed to [run], including any device/channel scope.
  bool busy(Operation operation) => _busy.contains(operation);

  /// Retains observations for an inspected characteristic until its service cache is retired.
  ValueListenable<List<int>?> observeCharacteristic(BluetoothCharacteristic characteristic) {
    final values = _characteristicValues.putIfAbsent(characteristic.remoteId, () => {});
    return values
        .putIfAbsent(Operation.characteristic(characteristic), () => _CharacteristicValue(characteristic, _streamError))
        .value;
  }

  /// Whether this workbench subscribed to [c] on web, which reports no subscription state itself.
  bool subscribedOnWeb(BluetoothCharacteristic c) =>
      _webSubscriptions[c.remoteId]?.contains(Operation.characteristic(c)) ?? false;

  void setSubscribedOnWeb(BluetoothCharacteristic c, {required bool subscribed, required int generation}) {
    if (!_isCurrentConnection(c.device, generation)) {
      return;
    }
    final subscriptions = _webSubscriptions.putIfAbsent(c.remoteId, () => {});
    if (subscribed) {
      subscriptions.add(Operation.characteristic(c));
    } else {
      subscriptions.remove(Operation.characteristic(c));
    }
    _update();
  }

  bool get supportsAdvertisementTracking =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get supportsMtu => supportsL2cap;

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
      FlutterBlueMax.onScanResults.listen((r) {
        _scanRevision++;
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
    _acceptSubscription = FlutterBlueMax.onL2capConnected.listen((event) {
      final channel = BluetoothL2capChannel(deviceId: event.remoteId, psm: event.psm);
      if (event.psm == serverPsm || _startingServer) {
        _trackChannel(channel, incoming: true);
        log('L2CAP accepted ${event.remoteId} / PSM ${event.psm}');
      } else {
        unawaited(_closeUnownedChannel(channel));
      }
    });
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
        _retireIdlePeer(event.remoteId);
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
          for (final remoteId in _peerSubscriptions.keys) {
            _invalidateConnection(remoteId);
          }
          rssi = null;
          mtu = null;
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
    log(problem.activity, severity: ActivitySeverity.error);
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

  /// Watches the selected peer and retires the previous peer when it has no active work.
  void select(BluetoothDevice device) {
    final previous = selected;
    selected = device;
    rssi = null;
    mtu = supportsMtu && device.isConnected ? device.mtuNow : null;
    if (!_peerSubscriptions.containsKey(device.remoteId)) {
      final subscriptions = _peerSubscriptions[device.remoteId] = [];
      subscriptions.add(
        device.onServicesReset.listen((_) {
          _invalidateServices(device.remoteId);
          log('Services changed on ${nameOf(device)}. Discover services again.');
        }),
      );
      // The stream first replays the cached state, which is `disconnected` for peers never connected over GATT.
      // That state is already applied here, so only later changes are handled and logged.
      var wasConnected = device.isConnected;
      subscriptions.add(
        device.connectionState.skip(1).listen((state) {
          final lostConnection = wasConnected && state == BluetoothConnectionState.disconnected;
          wasConnected = state == BluetoothConnectionState.connected;
          if (lostConnection) {
            _invalidateConnection(device.remoteId);
            if (selected == device) {
              rssi = null;
              mtu = null;
            }
            _closeOutgoingChannels(device.remoteId);
          }
          if (state == BluetoothConnectionState.connected && selected == device && supportsMtu) {
            mtu = device.mtuNow;
          }
          log(
            '${nameOf(device)}: ${state.name}'
            '${state == BluetoothConnectionState.disconnected ? ' · ${device.disconnectReason}' : ''}',
          );
          if (state == BluetoothConnectionState.connected && selected == device) {
            unawaited(_readRssiAutomatically(device));
          }
          _retireIdlePeer(device.remoteId);
        }),
      );
      subscriptions.add(
        device.mtu.listen((value) {
          if (selected == device && device.isConnected && supportsMtu) {
            mtu = value;
            _update();
          }
        }),
      );
    }
    if (device.isConnected) {
      unawaited(_readRssiAutomatically(device));
    }
    if (previous != null) {
      _retireIdlePeer(previous.remoteId);
    }
    _update();
  }

  void _retireIdlePeer(DeviceIdentifier remoteId) {
    final subscriptions = _peerSubscriptions[remoteId];
    if (subscriptions == null ||
        selected?.remoteId == remoteId ||
        connectingDevice?.remoteId == remoteId ||
        _openingPeer == remoteId ||
        BluetoothDevice(remoteId: remoteId).isConnected ||
        _channels.values.any((session) => !session.closed && session.channel.deviceId == remoteId)) {
      return;
    }
    _peerSubscriptions.remove(remoteId);
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  int connectionGeneration(BluetoothDevice device) => _connectionGenerations[device.remoteId] ?? 0;

  bool _isCurrentConnection(BluetoothDevice device, int generation) =>
      !_disposed && device.isConnected && connectionGeneration(device) == generation;

  void _invalidateConnection(DeviceIdentifier remoteId) {
    _connectionGenerations.update(remoteId, (generation) => generation + 1, ifAbsent: () => 1);
    _webSubscriptions.remove(remoteId);
    _invalidateServices(remoteId);
  }

  void _invalidateServices(DeviceIdentifier remoteId) {
    _serviceGenerations.update(remoteId, (generation) => generation + 1, ifAbsent: () => 1);
    _services.remove(remoteId);
    _retireCharacteristicValues(remoteId);
  }

  void _retireCharacteristicValues(DeviceIdentifier remoteId) {
    final values = _characteristicValues.remove(remoteId);
    if (values != null) {
      for (final observation in values.values) {
        observation.dispose();
      }
    }
  }

  /// Toggles scanning: a running scan is stopped rather than restarted.
  Future<void> scan() => run(Operation.scan, () async {
    if (scanning) {
      await FlutterBlueMax.stopScan();
      return;
    }
    if (!kIsWeb) {
      await refreshSystemDevices();
    }
    if (_disposed) {
      return;
    }
    _trackingScan = false;
    await _startOwnedScan(
      () => FlutterBlueMax.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
        // Preserve the original example's browser service permissions.
        webOptionalServices: [Guid('180f'), Guid('180a'), Guid('1800'), Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')],
      ),
    );
  });

  Future<void> refreshScan() async {
    if (!scanning && ready) {
      await scan();
    }
  }

  /// Reports every advertisement of one peer until stopped, replacing any running scan.
  Future<void> trackAdvertisements(BluetoothDevice device) => run(Operation.scan, () async {
    if (!supportsAdvertisementTracking) {
      throw const _Unsupported('Continuous per-peer advertisements are unavailable.');
    }
    if (scanning) {
      await FlutterBlueMax.stopScan();
    }
    if (_disposed) {
      return;
    }
    // The session a failed scan start would replace stays readable.
    final previousTracker = advertisementTracker;
    advertisementTracker = AdvertisementTracker(device.remoteId);
    _trackingScan = true;
    try {
      await _startOwnedScan(
        () => FlutterBlueMax.startScan(
          withRemoteIds: [device.remoteId.str],
          continuousUpdates: true,
          oneByOne: true,
          androidUsesFineLocation: true,
        ),
      );
    } catch (_) {
      advertisementTracker = previousTracker;
      _trackingScan = false;
      rethrow;
    }
    log('Tracking advertisements of ${nameOf(device)}');
  });

  Future<void> _startOwnedScan(Future<void> Function() start) async {
    final done = Completer<void>();
    _scanStartDone = done.future;
    try {
      await start();
      if (_disposed) {
        await FlutterBlueMax.stopScan();
      }
    } finally {
      _scanStartDone = null;
      done.complete();
    }
  }

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
      _retireIdlePeer(device.remoteId);
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
    final remoteId = device.remoteId;
    final generation = _serviceGenerations[remoteId];
    final result = await device.discoverServices();
    if (!_hasCurrentServices(device, generation)) {
      return;
    }
    _services[remoteId] = List.unmodifiable(result);
    log('${result.length} services discovered on ${nameOf(device)}');
    await _readUserDescriptions(device, result, generation);
  });

  bool _hasCurrentServices(BluetoothDevice device, int? generation) =>
      !_disposed && device.isConnected && generation == _serviceGenerations[device.remoteId];

  /// Labels characteristics the GATT catalog does not know.
  /// A failed read only loses that label.
  Future<void> _readUserDescriptions(BluetoothDevice device, List<BluetoothService> services, int? generation) async {
    final descriptors = services
        .expand((service) => service.characteristics)
        .expand((characteristic) => characteristic.descriptors)
        .where((descriptor) => descriptor.uuid == userDescriptionUuid);
    for (final descriptor in descriptors) {
      if (!_hasCurrentServices(device, generation)) {
        return;
      }
      try {
        await descriptor.read();
      } catch (exception, stackTrace) {
        log('User description of ${descriptor.characteristicUuid}: $exception');
        developer.log('Read user description failed', name: 'workbench', error: exception, stackTrace: stackTrace);
      }
      _update();
    }
  }

  Future<void> _readRssiAutomatically(BluetoothDevice device) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _refreshRssi(device);
    } catch (exception, stackTrace) {
      log('Automatic RSSI read failed: $exception', severity: ActivitySeverity.error);
      developer.log('Automatic RSSI read failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    }
  }

  Future<void> _refreshRssi(BluetoothDevice device) async {
    final generation = connectionGeneration(device);
    final value = await device.readRssi();
    if (selected == device && _isCurrentConnection(device, generation)) {
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

  Future<void> requestMtu(BluetoothDevice device, int value, {required int generation}) => run(Operation.mtu, () async {
    if (_isCurrentConnection(device, generation)) {
      await device.requestMtu(value);
    }
  });

  Future<void> startServer({required bool secure}) => _runServer(() async {
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
    serverPsm = psm;
    if (_disposed || !ready) {
      await _stopServer(psm);
      return;
    }
    await Future.wait(
      channels.where((s) => s.incoming && s.channel.psm != psm).map((s) => _closeUnownedChannel(s.channel)),
    );
    log('Server listening on PSM $psm (${secure ? 'secure' : 'insecure'})');
  });

  Future<void> _closeUnownedChannel(BluetoothL2capChannel channel) async {
    try {
      await channel.close();
      final session = _channels[(channel.deviceId, channel.psm)];
      if (session != null && session.incoming) {
        session.markClosed();
      }
      _update();
    } catch (exception, stackTrace) {
      developer.log('Closing late L2CAP accept', name: 'workbench', error: exception, stackTrace: stackTrace);
      if (_disposed) {
        return;
      }
      // Keep a failed native close reachable through the card's Close action.
      _trackChannel(channel, incoming: true);
      error = 'Closing late L2CAP accept: $exception';
      log('ERROR $error', severity: ActivitySeverity.error);
    }
  }

  Future<void> stopServer() => _runServer(() async {
    final psm = serverPsm;
    if (psm != null) {
      await _stopServer(psm);
    }
  });

  Future<void> _runServer(Future<void> Function() action) async {
    if (_disposed || busy(Operation.server)) {
      return;
    }
    final done = Completer<void>();
    _serverWork = done.future;
    try {
      await run(Operation.server, action);
    } finally {
      if (identical(_serverWork, done.future)) {
        _serverWork = null;
      }
      done.complete();
    }
  }

  Future<void> _stopServer(int psm) async {
    await FlutterBlueMax.stopL2capServer(psm);
    serverPsm = null;
    // Unpublishing on Apple stops accepting peers but leaves accepted streams open.
    // Close them explicitly, retaining any failed close in the UI for retry.
    final accepted = channels.where((s) => s.incoming && s.channel.psm == psm).toList();
    await Future.wait(
      accepted.map((s) async {
        await s.channel.close();
        s.markClosed();
        _retireIdlePeer(s.channel.deviceId);
      }),
    );
  }

  /// Binds an outgoing channel to the inspected peer, never to later device selection.
  Future<void> openChannel(int psm, {required BluetoothDevice device, required bool secure}) =>
      run(Operation.open, () async {
        _openingPeer = device.remoteId;
        try {
          await _openChannel(psm, device, secure: secure);
        } finally {
          _openingPeer = null;
          _retireIdlePeer(device.remoteId);
        }
      });

  Future<void> _openChannel(int psm, BluetoothDevice device, {required bool secure}) async {
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
        if (_disposed || !ready || userDisconnected || device.isConnected || _isUnsupported(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        log('L2CAP open failed; retrying once: $error');
        developer.log('L2CAP open failed; retrying', name: 'workbench', error: error, stackTrace: stackTrace);
        await device.connect(mtu: null);
        if (_disposed || !ready || (_disconnectRequests[device.remoteId] ?? 0) != disconnects) {
          Error.throwWithStackTrace(error, stackTrace);
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
  }

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
    _retireIdlePeer(session.channel.deviceId);
  });

  /// Outgoing channels belong to the GATT session that opened them.
  /// Incoming channels belong to the local server and stay untouched.
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
    final nativeKey = (channel.deviceId, channel.psm);
    final session = _channelSessions.putIfAbsent((
      channel.deviceId,
      channel.psm,
      incoming,
    ), () => ChannelSession(channel, incoming: incoming));
    // The plugin can route only one active session for a peer and PSM.
    _channels[nativeKey]?.markClosed();
    _channels[nativeKey] = session;
    session.reopen(channel);
  }

  /// Runs the action and reports failures through the error banner and Activity.
  /// Calls after disposal and duplicate in-flight actions complete without running the action.
  /// Awaiting this future only means the action was handled.
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
      log('ERROR ${operation.label}: $exception', severity: ActivitySeverity.error);
      developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    } finally {
      _busy.remove(operation);
      _update();
    }
  }

  Future<bool> copyToClipboard(String text) async {
    var copied = false;
    await run(Operation.clipboard, () async {
      await Clipboard.setData(ClipboardData(text: text));
      copied = true;
    });
    return copied;
  }

  void dismissError() {
    error = null;
    _update();
  }

  void clearLogs() {
    _activity.value = const [];
    _update();
  }

  void log(String message, {ActivitySeverity severity = ActivitySeverity.info}) {
    if (_disposed) {
      return;
    }
    final previous = _activity.value;
    _activity.value = List.unmodifiable([
      ...previous.skip(previous.length >= maxLogEntries ? 1 : 0),
      ActivityEntry('${clock.now().toIso8601String()}  $message', severity: severity),
    ]);
    _update();
  }

  void _streamError(Object exception, StackTrace stackTrace) {
    error = exception.toString();
    log('ERROR $error', severity: ActivitySeverity.error);
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
    _activity.dispose();
    for (final peer in _characteristicValues.keys.toList()) {
      _retireCharacteristicValues(peer);
    }
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    for (final subscriptions in _peerSubscriptions.values) {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    }
    // Navigation never disposes this controller; shutdown does. Native hot-restart
    // cleanup is still the fallback when the Dart isolate is terminated abruptly.
    _shutdownWork = _shutdown();
    unawaited(_shutdownWork);
    super.dispose();
  }

  /// Completes once resources owned by a disposed workbench have been retired.
  Future<void> get shutdownComplete => _shutdownWork ?? Future.value();

  Future<void> _shutdown() async {
    final pendingScan = _scanStartDone;
    await _cleanup(() async {
      try {
        // Keep the accept subscription alive through an in-flight start or stop
        // and through unpublishing. Apple leaves accepted channels open.
        await _serverWork;
        final psm = serverPsm;
        if (psm != null) {
          await _stopServer(psm);
        }
      } finally {
        await _acceptSubscription?.cancel();
      }
    });
    await _cleanup(() async {
      if (pendingScan != null) {
        await pendingScan;
      } else if (scanning) {
        await FlutterBlueMax.stopScan();
      }
    });
    final cleanup = <Future<void> Function()>[
      for (final session in channels)
        () async {
          await session.channel.close();
          session.markClosed();
        },
      for (final id in _peerSubscriptions.keys) () => BluetoothDevice(remoteId: id).disconnect(),
    ];
    for (final action in cleanup) {
      await _cleanup(action);
    }
  }

  Future<void> _cleanup(Future<void> Function() action) async {
    try {
      await action();
    } catch (exception, stackTrace) {
      developer.log('Bluetooth operation failed', name: 'workbench', error: exception, stackTrace: stackTrace);
    }
  }
}

class _CharacteristicValue(BluetoothCharacteristic characteristic, void Function(Object, StackTrace) onError) {
  this {
    final cached = characteristic.lastValue;
    value = ValueNotifier(cached.isEmpty ? null : List.unmodifiable(cached));
    // The first sample is the cache seed. A subsequent empty event is a real payload.
    _updates = characteristic.lastValueStream
        .skip(1)
        .listen((bytes) => value.value = List.unmodifiable(bytes), onError: onError);
  }

  late final ValueNotifier<List<int>?> value;
  late final StreamSubscription<List<int>> _updates;

  void dispose() {
    unawaited(_updates.cancel());
    value.dispose();
  }
}

/// Identifies an operation for [WorkbenchController.run] and [WorkbenchController.busy].
/// Operations with a [scope], such as one channel, run independently of each other.
class const Operation._(final _OperationKind _kind, [final Object? scope, final String? _detail]) {
  static const initialize = Operation._(_OperationKind.initialize);
  static const clipboard = Operation._(_OperationKind.clipboard);
  static const scan = Operation._(_OperationKind.scan);
  static const systemDevices = Operation._(_OperationKind.systemDevices);
  static const connection = Operation._(_OperationKind.connection);
  static const cancelConnection = Operation._(_OperationKind.cancelConnection);
  static const adapter = Operation._(_OperationKind.adapter);
  static const discover = Operation._(_OperationKind.discover);
  static const bond = Operation._(_OperationKind.bond);
  static const mtu = Operation._(_OperationKind.mtu);
  static const server = Operation._(_OperationKind.server);
  static const open = Operation._(_OperationKind.open);

  new rssi(BluetoothDevice device) : this._(_OperationKind.rssi, device.remoteId);
  new channel(ChannelSession session) : this._(_OperationKind.channel, session.key);
  new characteristic(BluetoothCharacteristic c)
    : this._(_OperationKind.characteristic, (
        c.remoteId,
        c.primaryServiceUuid,
        c.serviceUuid,
        c.uuid,
        c.instanceId,
      ), c.uuid.toString());
  new descriptor(BluetoothDescriptor d)
    : this._(_OperationKind.descriptor, (
        d.remoteId,
        d.serviceUuid,
        d.characteristicUuid,
        d.uuid,
        d.instanceId,
      ), d.uuid.toString());

  /// Prefixes the error the operation reports.
  String get label => _detail == null ? _kind.label : '${_kind.label} $_detail';

  @override
  bool operator ==(Object other) => other is Operation && other._kind == _kind && other.scope == scope;

  @override
  int get hashCode => Object.hash(_kind, scope);
}

enum _OperationKind(final String label) {
  initialize('Initialize'),
  clipboard('Copy to clipboard'),
  scan('Scan'),
  systemDevices('System devices'),
  connection('Connection'),
  cancelConnection('Cancel connection'),
  adapter('Turn on Bluetooth'),
  discover('Service discovery'),
  bond('Bond'),
  mtu('MTU request'),
  server('L2CAP server'),
  open('Open L2CAP channel'),
  rssi('Read RSSI'),
  channel('L2CAP channel'),
  characteristic('Characteristic'),
  descriptor('Descriptor'),
}

enum ActivitySeverity() {
  info,
  error,
}

/// A formatted session log line and its severity for Activity.
class const ActivityEntry(final String text, {required final ActivitySeverity severity});

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
