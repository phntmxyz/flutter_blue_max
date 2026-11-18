import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_platform_interface/flutter_blue_max_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_bluetooth_platform.dart';
import '../robot/advertisement_robot.dart';
import '../robot/catalog_files_robot.dart';
import '../robot/diagnostics_robot.dart';
import '../robot/file_dialogs_robot.dart';
import '../robot/gatt_catalog_robot.dart';
import '../robot/parser_files_robot.dart';
import '../robot/workbench_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeBluetoothPlatform();
  // Plugin subscriptions outlive each widget test's fake clock, as they do app screens.
  setUpAll(() async {
    FlutterBlueMaxPlatform.instance = platform;
    await FlutterBlueMax.setLogLevel(LogLevel.verbose, color: false);
  });

  testWidgets('discovery: a peer in both lists can be selected unambiguously', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 1000));
    await robot.selectAdvertisedPeerAlsoConnectedToTheSystem();
  });

  testWidgets('parser editor: hidden inputs do not prevent saving after a type change', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 1000));
    await robot.scanForSensor();
    await robot.saveAfterChangingFieldType();
  });

  testWidgets('parser editor: rejects negative hex identifiers', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 1000));
    await robot.scanForSensor();
    await robot.rejectNegativeHexIdentifiers();
  });

  testWidgets('desktop: discover GATT, validate PSM and preserve server across navigation', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    robot.expectLocalDeviceName();
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.readAndWriteCharacteristic();
    await robot.openL2cap();
    await robot.rejectInvalidRemotePsm();
    await robot.openRemoteChannel();
    robot.expectChannelEncryption(secure: true);
    await robot.openLocalServer();
    robot.expectNoOutgoingChannels();
    await robot.startServer();
    robot.expectServerEncryption(secure: true);
    await robot.openActivity();
    await robot.openLocalServer();
    robot.expectListening();
    await robot.stopServer();
    robot.expectStopped();
  });

  testWidgets('phone: local server is available without selecting a peripheral', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    robot.expectLocalDeviceName();
    await robot.openLocalServer();
    await robot.turnOffEncryption();
    await robot.startServer();
    robot.expectServerEncryption(secure: false);
    await robot.openActivity();
    await robot.openLocalServer();
    robot.expectListening();
    await robot.acceptIncomingChannel();
    await robot.stopServer();
    robot.expectStopped();
  });

  testWidgets('compact phone: keyboard and landscape keep workspaces scrollable', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(360, 640));
    await robot.scanForPeripheral();
    await robot.filterWithKeyboard();
    await robot.rotateToLandscape();
    await robot.openLocalServer();
    await robot.startServer();
    await robot.openActivity();
    await robot.openLocalServer();
    await robot.stopServer();
  });

  testWidgets('phone: track the advertisements of a selected device', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.selectPeripheral();
    await robot.trackAdvertisements();
  });

  testWidgets('phone: parse sensor values and filter the tracked history', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForSensor();
    await robot.addTemperatureParser();
    await robot.filterTrackedHistory();
    await robot.removeParser();
  });

  testWidgets('phone: parse a record-based sensor frame', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForRecordSensor();
    await robot.addRecordParser();
  });

  testWidgets('desktop: manage saved parsers globally', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.manageGlobalParsers();
  });

  group('File dialog outcomes', () {
    for (final library in LibraryFile.values) {
      testWidgets('$library: a failing share reports the export error', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(390, 844));
        await robot.rejectShareFailure(library);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      testWidgets('$library: dismissing a share does not claim an export', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(390, 844));
        await robot.dismissShare(library);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      testWidgets('$library: a picker failure keeps the library intact', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(1200, 850));
        await robot.rejectPickerFailure(library);
      });
      testWidgets('$library: cancelling a picker leaves the library alone', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(1200, 850));
        await robot.cancelFilePicker(library);
      });
      testWidgets('$library: an unconfirmed share does not claim an export', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(390, 844));
        await robot.shareWithoutConfirmation(library);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      testWidgets('$library: a failing save dialog reports the export error', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(1200, 850));
        await robot.rejectDesktopSaveFailure(library);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
      testWidgets('$library: cancelling a save does not claim an export', (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(1200, 850));
        await robot.cancelDesktopSave(library);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  });

  testWidgets('clipboard rejection is reported from all diagnostic copy actions', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.rejectDiagnosticClipboardWrites();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  group('Parser files', () {
    testWidgets('phone: export chosen parsers through the share sheet', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(390, 844));
      await robot.exportChosenThroughShareSheet();
    });

    testWidgets('desktop: export all parsers to a file', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.exportAllToFile();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('desktop: import adds only parsers that are not present', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.importSkippingPresentParsers();
    });

    testWidgets('desktop: a file without parsers is rejected', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.rejectFileWithoutParsers();
    });

    testWidgets('desktop: a parser the editor would not save is rejected', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.rejectParserWithoutCompanyId();
    });

    testWidgets('desktop: reset replaces every parser with the bundled ones', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.resetToBundledParsers();
    });
  });

  group('Catalog files', () {
    testWidgets('desktop: duplicate service UUIDs fail before the import chooser', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.rejectDuplicateServiceUuids();
    });

    testWidgets('desktop: import replaces own entries with the same UUID and skips identical ones', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.importReplacingOwnEntries();
    });

    testWidgets('phone: export chosen own services through the share sheet', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(390, 844));
      await robot.exportChosenServicesThroughShareSheet();
    });

    testWidgets('desktop: a parser file is rejected as catalog', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.rejectParserFileAsCatalog();
    });

    testWidgets('desktop: reset removes own services and keeps the built-in ones', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.resetOwnServices();
    });
  });

  testWidgets('phone: system back returns to the list without dropping the connection', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.returnToDeviceList();
    await robot.reopenConnectedPeripheral();
  });

  testWidgets('phone: system Back bubbles when another destination hides the inspector', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.backWithHiddenInspector();
  });

  testWidgets('phone: the search text survives a visit to the device details', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral(includeSecondPeer: true);
    await robot.keepSearchAcrossDetails();
  });

  testWidgets('android: request an MTU in range and create a bond', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.scanForPeripheral();
    await robot.selectPeripheral();
    await robot.connectSelected();
    await robot.requestMtuAndCreateBond();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: tapping outside a text field closes the keyboard', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.dismissKeyboardByTappingOutside();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('GATT payload keeps its draft when a background tap dismisses the keyboard', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.dismissGattPayloadKeyboard();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: outgoing L2CAP requires a connection but no GATT discovery', (tester) async {
    // Only Android lets the client choose encryption.
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(390, 844));
    await robot.scanForPeripheral();
    await robot.selectPeripheral();
    await robot.openL2cap();
    robot.expectConnectionRequired();
    await robot.connectSelected();
    await robot.turnOffEncryption();
    await robot.openRemoteChannel();
    robot.expectChannelEncryption(secure: false);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('desktop: channels and remote PSM input belong to the inspected device', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.scanForPeripheral(includeSecondPeer: true);
    await robot.selectPeripheral();
    await robot.connectSelected();
    await robot.openL2cap();
    await robot.openRemoteChannel();
    await robot.selectPeripheral(name: 'Other peripheral');
    await robot.connectSelected();
    await robot.openL2cap();
    robot.expectEmptyPsm();
    await robot.openRemoteChannel();
    await robot.selectPeripheral();
    await robot.openL2cap();
    await robot.expectOnlySelectedChannel();
  });

  testWidgets('unsupported server reports a dismissible message and GATT remains usable', (tester) async {
    final robot = WorkbenchRobot(tester, platform);
    await robot.launch(size: const Size(1200, 850));
    await robot.openLocalServer();
    await robot.rejectUnsupportedServer();
    await robot.dismissUnsupportedError();
    await robot.openDevices();
    await robot.scanForPeripheral();
    await robot.inspectPeripheral();
    await robot.readAndWriteCharacteristic();
  });
  group('Platform controls and diagnostics', () {
    testWidgets('system-connected peers remain discoverable without advertisements', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.connectSystemPeer();
    });

    testWidgets('phone: cancel a pending connection', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(390, 844));
      await robot.scanForPeripheral();
      await robot.selectPeripheral();
      await robot.cancelPendingConnection();
    });

    testWidgets('L2CAP exposes large writes, burst traffic, buffer reads and receive history', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.scanForPeripheral();
      await robot.selectPeripheral();
      await robot.connectSelected();
      await robot.openL2cap();
      await robot.openRemoteChannel();
      await robot.exerciseL2capTraffic();
      await robot.inspectHistoryAfterClosing(fromPeer: false);
    });

    testWidgets('incoming channel history remains visible after the peer closes it', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.openLocalServer();
      await robot.startServer();
      await robot.acceptIncomingChannel();
      await robot.exerciseL2capTraffic();
      await robot.inspectHistoryAfterClosing(fromPeer: true);
    });

    testWidgets('GATT subscriptions and descriptor operations remain reachable', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.scanForPeripheral();
      await robot.inspectPeripheralWithDescriptors();
      await robot.exerciseNotificationsAndDescriptors();
    });

    testWidgets('known GATT services are named and test services checked against the dongle', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.scanForPeripheral();
      await robot.discoverPartialTestDongle();
      robot.expectNamedServices();
      await robot.inspectTestCharacteristics();
    });

    testWidgets('a discovered service can be added to the GATT catalog and removed again', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.scanForPeripheral();
      await robot.addDiscoveredServiceToCatalog();
      await robot.removeOwnCatalogService();
    });

    testWidgets('a custom GATT entry overrides Battery until removed', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.scanForPeripheral();
      await robot.overrideBuiltInBatteryService();
    });

    testWidgets('broadcast advertisements retain appearance and cannot be connected', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(390, 844));
      await robot.checkBroadcastAndAppearance();
    });

    testWidgets('Android exposes the adapter turn-on action', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(390, 844));
      await robot.enableBluetooth();
    });

    testWidgets('phone: pull-to-refresh starts a new scan', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(390, 844));
      await robot.pullToRefreshDevices();
    });

    testWidgets('Linux exposes GATT and activity without unsupported L2CAP controls', (tester) async {
      final robot = WorkbenchRobot(tester, platform);
      await robot.launch(size: const Size(1200, 850));
      await robot.scanForPeripheral();
      await robot.inspectPeripheral();
      robot.expectGattOnlyPlatform();
      await robot.readAndWriteCharacteristic();
      await robot.openActivity();
      await robot.openDevices();
      robot.expectGattOnlyPlatform();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    for (final size in [const Size(1200, 850), const Size(390, 844)]) {
      testWidgets(
        'web: scan, GATT and navigation at $size',
        (tester) async {
          final robot = WorkbenchRobot(tester, platform);
          await robot.launch(size: size);
          robot.serveWebGatt();
          await robot.scanForPeripheral();
          await robot.inspectPeripheral();
          robot.expectWebCapabilities();
          await robot.exerciseNotificationsAndDescriptors();
          await robot.openActivity();
          await robot.openDevices();
          robot.expectWebCapabilities();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
        skip: !kIsWeb,
      );
    }

    testWidgets(
      'web: a subscription survives rebuilding its tile until the link drops',
      (tester) async {
        final robot = WorkbenchRobot(tester, platform);
        await robot.launch(size: const Size(1200, 850));
        robot.serveWebGatt();
        await robot.scanForPeripheral(includeSecondPeer: true);
        await robot.inspectPeripheral();
        await robot.keepWebSubscriptionUntilDisconnect();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      skip: !kIsWeb,
    );
  });
}
