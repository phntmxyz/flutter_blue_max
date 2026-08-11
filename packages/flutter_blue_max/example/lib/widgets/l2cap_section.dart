import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';

import '../utils/extra.dart';
import '../utils/snackbar.dart';

class L2CapSection extends StatefulWidget {
  const L2CapSection({super.key, required this.device});

  final BluetoothDevice device;

  @override
  State<L2CapSection> createState() => _L2CapSectionState();
}

class _L2CapSectionState extends State<L2CapSection> with SingleTickerProviderStateMixin {
  // Connection state
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  // L2CAP related state
  final Map<int, BluetoothL2capChannel> _activeL2CapChannels = {};
  bool _isListeningL2Cap = false;
  int? _listeningPsm;
  final TextEditingController _psmController = TextEditingController();
  final TextEditingController _l2capDataController = TextEditingController();
  final List<String> _l2capReceivedList = [];
  int _rxBytesTotal = 0;
  StreamSubscription<L2CapChannelData>? _l2capSubscription;
  StreamSubscription<L2CapChannelConnected>? _l2capConnectedSubscription;
  StreamSubscription<L2CapChannelClosed>? _l2capClosedSubscription;
  bool _l2capSecure = false;
  bool _isServerMode = true;
  bool _hasValidPsm = false;

  static const int _maxLogEntries = 300;
  static const int _maxDataEntries = 200;

  void _onPsmControllerChanged() {
    {
      final int? psm = int.tryParse(_psmController.text);
      final isInvalid = psm == null || (psm < 1 || psm > 65535);
      setState(() {
        _hasValidPsm = !isInvalid;
      });
    }
  }

  // Logs
  final List<String> _logMessages = [];
  StreamSubscription<String>? _logsSubscription;

  // Tabs: 0 => Data, 1 => Logs
  late TabController _tabController;

  bool get isConnected => _connectionState == BluetoothConnectionState.connected;

  void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    _logMessages.insert(0, '[$ts] $message');
    if (_logMessages.length > _maxLogEntries) {
      _logMessages.removeRange(_maxLogEntries, _logMessages.length);
    }
    if (mounted && _tabController.index == 1) {
      setState(() {});
    }
  }

  void _addReceivedEntry(String entry) {
    _l2capReceivedList.insert(0, entry);
    if (_l2capReceivedList.length > _maxDataEntries) {
      _l2capReceivedList.removeRange(_maxDataEntries, _l2capReceivedList.length);
    }
  }

  // Show text payloads as text, binary payloads as a length + hex preview
  String _formatBytes(List<int> value) {
    if (value.isEmpty) {
      return '0 bytes';
    }
    final bool printable =
        value.every((b) => b == 0x09 || b == 0x0a || b == 0x0d || (b >= 0x20 && b <= 0x7e));
    if (printable) {
      return utf8.decode(value, allowMalformed: true);
    }
    final hex = value.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return '${value.length} bytes: $hex${value.length > 16 ? ' …' : ''}';
  }

  /// The channel addressed by the PSM text field, or null if none is open.
  BluetoothL2capChannel? _channelForPsmField() {
    final int? psm = int.tryParse(_psmController.text);
    return psm != null ? _activeL2CapChannels[psm] : null;
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Rebuild UI when PSM text changes so buttons update enabled state
    _psmController.addListener(_onPsmControllerChanged);

    _connectionStateSubscription = widget.device.connectionState.listen((state) async {
      _connectionState = state;
      // Auto-reset L2CAP state when the peer disconnects
      if (state == BluetoothConnectionState.disconnected) {
        await resetL2cap(keepServerListening: true);
      }
      if (mounted) setState(() {});
    });

    // Subscribe to FBP logs for the Logs view
    _logsSubscription = FlutterBlueMax.logs.listen((line) {
      _logMessages.insert(0, line);
      if (_logMessages.length > _maxLogEntries) {
        _logMessages.removeRange(_maxLogEntries, _logMessages.length);
      }
      if (mounted && _tabController.index == 1) {
        setState(() {});
      }
    });

    // Subscribe to L2CAP received data, scoped to the channels this screen
    // opened or accepted (matched by device + PSM, not PSM alone)
    _l2capSubscription = FlutterBlueMax.onL2capReceived.listen((evt) {
      final channel = _activeL2CapChannels[evt.psm];
      if (channel == null || channel.deviceId != evt.remoteId) return;

      _rxBytesTotal += evt.value.length;
      final receivedData = _formatBytes(evt.value);
      _log('L2CAP RX psm=${evt.psm} remote=${evt.remoteId.str} bytes=${evt.value.length} data="$receivedData"');
      _addReceivedEntry(receivedData);
      if (mounted && _tabController.index == 0) {
        setState(() {});
      }
    });

    // A client connected to our L2CAP server: track the accepted channel so
    // Send/Read target it. The event's remoteId is the client's MAC address
    // on Android and the placeholder 'server' on iOS.
    _l2capConnectedSubscription = FlutterBlueMax.onL2capConnected.listen((evt) {
      if (!_isListeningL2Cap || evt.psm != _listeningPsm) return;
      _log('Server: client connected remote=${evt.remoteId.str} psm=${evt.psm}');
      if (!mounted) return;
      setState(() {
        _activeL2CapChannels[evt.psm] = BluetoothL2capChannel(deviceId: evt.remoteId, psm: evt.psm);
      });
    });

    // The remote closed a channel (or it died from a stream error/disconnect):
    // drop it from the UI instead of finding out on the next failed write
    _l2capClosedSubscription = FlutterBlueMax.onL2capClosed.listen((evt) {
      final channel = _activeL2CapChannels[evt.psm];
      if (channel == null || channel.deviceId != evt.remoteId) return;
      _log('Channel closed by remote remote=${evt.remoteId.str} psm=${evt.psm}');
      Snackbar.show(ABC.c, "L2CAP channel closed - PSM: ${evt.psm}", success: false);
      if (!mounted) return;
      setState(() {
        _activeL2CapChannels.remove(evt.psm);
      });
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _psmController.removeListener(_onPsmControllerChanged);
    _psmController.dispose();
    _l2capDataController.dispose();
    _logsSubscription?.cancel();
    _l2capSubscription?.cancel();
    _l2capConnectedSubscription?.cancel();
    _l2capClosedSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // L2CAP Methods
  Future<void> resetL2cap({bool keepServerListening = true, bool clearLogs = false}) async {
    // Close the client channels opened to this screen's device. Server-accepted
    // channels are left alone — their lifecycle is driven by the
    // onL2capConnected / onL2capClosed events and by stopping the server.
    final channelsToClose = _activeL2CapChannels.values
        .where((ch) => ch.deviceId == widget.device.remoteId)
        .toList(growable: false);

    for (final ch in channelsToClose) {
      try {
        await ch.close();
      } catch (_) {
        // ignore errors while closing
      }
    }

    // Optionally stop server listener
    if (!keepServerListening && _isListeningL2Cap && _listeningPsm != null) {
      try {
        await FlutterBlueMax.stopL2capServer(_listeningPsm!);
      } catch (_) {
        // ignore errors while stopping
      }
    }

    if (!mounted) return;
    setState(() {
      _l2capDataController.clear();
      _l2capReceivedList.clear();
      _rxBytesTotal = 0;
      if (clearLogs) _logMessages.clear();

      for (final ch in channelsToClose) {
        _activeL2CapChannels.remove(ch.psm);
      }
      if (!keepServerListening) {
        _activeL2CapChannels.clear();
        _isListeningL2Cap = false;
        _listeningPsm = null;
      }

      _psmController.text = _listeningPsm?.toString() ?? '';
    });
  }

  Future onStartL2CapServerPressed() async {
    if (_isListeningL2Cap) {
      Snackbar.show(ABC.c, "L2CAP Server already running", success: false);
      return;
    }

    try {
      var psm = await FlutterBlueMax.listenL2capChannel(secure: _l2capSecure);

      setState(() {
        _isListeningL2Cap = true;
        _listeningPsm = psm;
        // Update the PSM text field with the actual assigned PSM.
        // The accepted channel is added once onL2capConnected fires.
        _psmController.text = psm.toString();
      });

      Snackbar.show(ABC.c, "L2CAP Server started on PSM: $_listeningPsm", success: true);
      // ignore: avoid_print
      print("L2CAP Server started - PSM: $_listeningPsm, Secure: $_l2capSecure");
      _log('Server listening started psm=$psm secure=$_l2capSecure');
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Start L2CAP Server Error:", e), success: false);
      // ignore: avoid_print
      print(e);
      // ignore: avoid_print
      print("backtrace: $backtrace");
      _log('Server listening start error psm=${_listeningPsm ?? -1} err=$e');
    }
  }

  Future onStopL2CapServerPressed() async {
    if (!_isListeningL2Cap) {
      Snackbar.show(ABC.c, "No L2CAP Server running", success: false);
      return;
    }

    try {
      await FlutterBlueMax.stopL2capServer(_listeningPsm!);

      setState(() {
        _isListeningL2Cap = false;
        // remove server-side channel placeholder if present
        _activeL2CapChannels.remove(_listeningPsm);
        _listeningPsm = null;
      });

      Snackbar.show(ABC.c, "L2CAP Server stopped", success: true);
      _log('Server listening stopped');
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Stop L2CAP Server Error:", e), success: false);
      // ignore: avoid_print
      print(e);
      // ignore: avoid_print
      print("backtrace: $backtrace");
      _log('Server listening stop error psm=$_listeningPsm err=$e');
    }
  }

  Future onConnectL2CapPressed() async {
    if (!_hasValidPsm) return;
    final int psm = int.parse(_psmController.text);

    if (_activeL2CapChannels.containsKey(psm)) {
      Snackbar.show(ABC.c, "L2CAP channel already open for PSM: $psm", success: false);
      return;
    }

    try {
      // Ensure we're connected (secure handshake may have dropped connection)
      if (!isConnected) {
        await widget.device.connectAndUpdateStream();
      }
      _log('Opening client channel psm=$psm secure=$_l2capSecure');
      var channel = await widget.device.openL2CapChannel(psm, secure: _l2capSecure);

      setState(() {
        _activeL2CapChannels[psm] = channel;
      });

      Snackbar.show(ABC.c, "L2CAP channel opened - PSM: $psm", success: true);
      // ignore: avoid_print
      print("L2CAP Channel opened - Device: ${widget.device.remoteId}, PSM: $psm, Secure: $_l2capSecure");
      _log('Client channel opened psm=$psm');
    } catch (e) {
      // Retry once after reconnect if secure handshake caused a transient drop
      try {
        if (!isConnected) {
          await widget.device.connectAndUpdateStream();
        }
        var channel = await widget.device.openL2CapChannel(psm, secure: _l2capSecure);
        setState(() {
          _activeL2CapChannels[psm] = channel;
        });
        Snackbar.show(ABC.c, "L2CAP channel opened after retry - PSM: $psm", success: true);
        // ignore: avoid_print
        print("L2CAP Channel opened after retry - Device: ${widget.device.remoteId}, PSM: $psm, Secure: $_l2capSecure");
        _log('Client channel opened after retry psm=$psm');
      } catch (e2, bt2) {
        Snackbar.show(ABC.c, prettyException("Open L2CAP Channel Error:", e2), success: false);
        // ignore: avoid_print
        print(e2);
        // ignore: avoid_print
        print("backtrace: $bt2");
        _log('Client channel open retry error psm=$psm err=$e2');
      }
    }
  }

  Future onDisconnectL2CapPressed() async {
    final channel = _channelForPsmField();
    if (channel == null) {
      Snackbar.show(ABC.c, "No L2CAP channel open for PSM: ${_psmController.text}", success: false);
      return;
    }
    final int psm = channel.psm;

    try {
      _log('Closing client channel psm=$psm');
      await channel.close();

      setState(() {
        _activeL2CapChannels.remove(psm);
      });

      Snackbar.show(ABC.c, "L2CAP channel closed - PSM: $psm", success: true);
      _log('Client channel closed psm=$psm');
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Close L2CAP Channel Error:", e), success: false);
      // ignore: avoid_print
      print(e);
      // ignore: avoid_print
      print("backtrace: $backtrace");
      _log('Client channel close error psm=$psm err=$e');
    }
  }

  Future onWriteL2CapPressed() async {
    String data = _l2capDataController.text;

    if (data.isEmpty) {
      Snackbar.show(ABC.c, "Please enter data to send", success: false);
      return;
    }

    final channel = _channelForPsmField();
    if (channel == null) {
      Snackbar.show(ABC.c, "No L2CAP channel open for PSM: ${_psmController.text}", success: false);
      return;
    }
    final int psm = channel.psm;

    try {
      final List<int> bytes = utf8.encode(data);

      _log('Write attempt psm=$psm len=${bytes.length}');
      await channel.write(bytes);

      Snackbar.show(ABC.c, "L2CAP data sent - ${bytes.length} bytes", success: true);
      _l2capDataController.clear();
      _log('Write success psm=$psm len=${bytes.length}');
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Write L2CAP Channel Error:", e), success: false);
      // ignore: avoid_print
      print(e);
      // ignore: avoid_print
      print("backtrace: $backtrace");
      _log('Write error psm=$psm err=$e');
    }
  }

  // Patterned payload (byte i = i & 0xff) so truncated or corrupted data is
  // recognizable on the receiving side
  List<int> _testPayload(int length) => List<int>.generate(length, (i) => i & 0xff);

  /// Sends one large payload — exercises SDU handling above the MTU size.
  Future onSendTestPayloadPressed() async {
    final channel = _channelForPsmField();
    if (channel == null) {
      Snackbar.show(ABC.c, "No L2CAP channel open for PSM: ${_psmController.text}", success: false);
      return;
    }
    const int size = 10 * 1024;

    try {
      _log('Write attempt psm=${channel.psm} len=$size (test payload)');
      await channel.write(_testPayload(size));
      Snackbar.show(ABC.c, "L2CAP test payload sent - $size bytes", success: true);
      _log('Write success psm=${channel.psm} len=$size (test payload)');
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write L2CAP Channel Error:", e), success: false);
      _log('Write error psm=${channel.psm} err=$e');
    }
  }

  /// Fires many writes without awaiting in between — exercises write
  /// queueing and backpressure handling.
  Future onSendBurstPressed() async {
    final channel = _channelForPsmField();
    if (channel == null) {
      Snackbar.show(ABC.c, "No L2CAP channel open for PSM: ${_psmController.text}", success: false);
      return;
    }
    const int count = 20;
    const int size = 1024;

    _log('Burst write attempt psm=${channel.psm} ${count}x$size bytes');
    final results = await Future.wait(
      List.generate(count, (_) {
        return channel.write(_testPayload(size)).then((_) => true).catchError((e) {
          _log('Burst write error psm=${channel.psm} err=$e');
          return false;
        });
      }),
    );
    final int ok = results.where((r) => r).length;
    Snackbar.show(ABC.c, "L2CAP burst: $ok/$count writes succeeded", success: ok == count);
    _log('Burst write done psm=${channel.psm} ok=$ok/$count');
  }

  Future onReadL2CapPressed() async {
    final channel = _channelForPsmField();
    if (channel == null) {
      Snackbar.show(ABC.c, "No L2CAP channel open for PSM: ${_psmController.text}", success: false);
      return;
    }

    try {
      final result = await channel.read();

      if (result.isNotEmpty) {
        setState(() {
          _addReceivedEntry(_formatBytes(result));
        });
      }

      Snackbar.show(ABC.c, result.isEmpty ? "L2CAP read - no data available" : "L2CAP read - ${result.length} bytes",
          success: true);
      _log('Read psm=${channel.psm} bytes=${result.length}');
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Read L2CAP Channel Error:", e), success: false);
      // ignore: avoid_print
      print(e);
      // ignore: avoid_print
      print("backtrace: $backtrace");
      _log('Read error psm=${channel.psm} err=$e');
    }
  }

  // (PSM validation is enforced by input formatter + live state in _hasValidPsm)

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'L2CAP',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Client'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Switch(
                      value: _isServerMode,
                      onChanged: (_isListeningL2Cap || _activeL2CapChannels.isNotEmpty)
                          ? null
                          : (value) => setState(() {
                                _isServerMode = value;
                                // Keep tab on Data by default; do not auto-switch to Logs
                              }),
                    ),
                  ),
                  const Text('Server'),
                ],
              ),
            ],
          ),
        ),

        // PSM Input and Security Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _psmController,
                  decoration: InputDecoration(
                    labelText: _isServerMode ? 'Assigned PSM' : 'PSM (1–65535)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isServerMode,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  const Text('Secure'),
                  Switch(
                    value: _l2capSecure,
                    onChanged: (value) => setState(() => _l2capSecure = value),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Server or Client controls
        if (_isServerMode) _buildL2CapServerControl(context) else _buildL2CapClientControl(context),

        const SizedBox(height: 16),

        // Tabs: Data / Logs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Data Transfer'),
              Tab(text: 'Logs'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Tab contents
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Data tab
                Builder(builder: (context) {
                  final bool canSend = _isServerMode
                      ? (_listeningPsm != null && _activeL2CapChannels.containsKey(_listeningPsm))
                      : _activeL2CapChannels.isNotEmpty;
                  return L2CapListSection(
                    entries: _l2capReceivedList,
                    title: 'Data Transfer',
                    actions: [
                      if (!canSend)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _isServerMode
                                ? (_isListeningL2Cap
                                    ? 'Waiting for a client to connect…'
                                    : 'Start the server to enable sending')
                                : 'Open a channel to enable sending',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      TextField(
                        onEditingComplete: canSend ? onWriteL2CapPressed : null,
                        controller: _l2capDataController,
                        decoration: InputDecoration(
                          labelText: 'Data to send',
                          border: const OutlineInputBorder(),
                          hintText: 'Enter data to send over L2CAP...',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              onPressed: canSend ? onWriteL2CapPressed : null,
                              icon: const Icon(Icons.send, size: 16),
                            ),
                          ),
                        ),
                        maxLines: 1,
                        enabled: true,
                      ),
                      // Test traffic: one large payload (SDU/MTU handling) and a
                      // write burst (queueing/backpressure)
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: canSend ? onSendTestPayloadPressed : null,
                            icon: const Icon(Icons.data_usage, size: 16),
                            label: const Text('Send 10 KB'),
                          ),
                          TextButton.icon(
                            onPressed: canSend ? onSendBurstPressed : null,
                            icon: const Icon(Icons.bolt, size: 16),
                            label: const Text('Burst 20×1 KB'),
                          ),
                        ],
                      ),
                    ],
                    topRightWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RX $_rxBytesTotal B',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: onReadL2CapPressed,
                          icon: const Icon(Icons.download),
                          label: const Text('Read Data'),
                        ),
                      ],
                    ),
                  );
                }),
                // Logs tab
                L2CapListSection(
                  entries: _logMessages,
                  title: 'Activity Log',
                  topRightWidget: TextButton(
                    onPressed: () => setState(() => _logMessages.clear()),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Padding _buildL2CapServerControl(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('L2CAP Server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isListeningL2Cap ? null : onStartL2CapServerPressed,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: !_isListeningL2Cap ? null : onStopL2CapServerPressed,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_isListeningL2Cap)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Server listening on PSM: $_listeningPsm (${_l2capSecure ? "Secure" : "Insecure"})',
                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
              ),
            ),
          if (_isListeningL2Cap)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Builder(builder: (context) {
                final client = _listeningPsm != null ? _activeL2CapChannels[_listeningPsm] : null;
                return Text(
                  client != null ? 'Client connected: ${client.deviceId.str}' : 'Waiting for a client to connect…',
                  style: TextStyle(color: client != null ? Colors.green[700] : Colors.grey),
                );
              }),
            ),
        ],
      ),
    );
  }

  Padding _buildL2CapClientControl(BuildContext context) {
    final int? currentPsm = int.tryParse(_psmController.text);

    final bool canClose = isConnected && currentPsm != null && _activeL2CapChannels.containsKey(currentPsm);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('L2CAP Client', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _hasValidPsm ? onConnectL2CapPressed : null,
                icon: const Icon(Icons.link),
                label: const Text('Open Channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canClose ? onDisconnectL2CapPressed : null,
                icon: const Icon(Icons.link_off),
                label: const Text('Close Channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_activeL2CapChannels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Active channels: ${_activeL2CapChannels.keys.join(", ")}',
                style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class L2CapListSection extends StatelessWidget {
  const L2CapListSection(
      {super.key,
      required this.entries,
      required this.title,
      this.onClear,
      this.actions = const [],
      this.topRightWidget});

  final String title;
  final List<String> entries;
  final void Function()? onClear;
  final List<Widget> actions;
  final Widget? topRightWidget;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.list_alt, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                topRightWidget ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),
            if (actions.isNotEmpty) ...actions,
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.grey[50],
                ),
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          'No entries yet...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              entries[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
