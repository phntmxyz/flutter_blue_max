import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:spot/spot.dart';

import 'workbench_robot.dart';

enum LibraryFile() {
  parsers,
  catalog,
}

/// File-dialog outcomes expressed through the real Library screens.
extension FileDialogsRobot on WorkbenchRobot {
  Future<void> _openFileLibrary(LibraryFile library) async {
    if (library == LibraryFile.catalog) {
      await controller.saveCatalogService(KnownService(Guid('fff0'), 'Sensor', []));
    }
    await tapLabel('Library');
    if (library == LibraryFile.catalog) await tapLabel('GATT catalog');
  }

  Future<void> _confirmExport(LibraryFile library) async {
    await tapLabel('Export');
    if (library == LibraryFile.catalog) {
      await tapInDialog('Export 1 service');
      return;
    }
    await tapInDialog('Export ${testDongleParsers.length} parsers');
  }

  void _expectNoExportSuccess() {
    spot<SnackBar>().spotText('Exported').doesNotExist();
  }

  Future<void> rejectShareFailure(LibraryFile library) async {
    logEvent('Report a failing share sheet without a success message');
    share.overrideShare = (params) {
      share.shared.add(params);
      return Future<ShareResult>.error(PlatformException(code: 'share_failed', message: 'Share unavailable'));
    };
    await _openFileLibrary(library);
    await _confirmExport(library);
    expect(share.shared, hasLength(1));
    spot<SnackBar>()
        .spotText('Export failed: PlatformException(share_failed, Share unavailable, null, null)', exact: true)
        .existsOnce();
    _expectNoExportSuccess();
  }

  Future<void> dismissShare(LibraryFile library) async {
    logEvent('Dismiss the share sheet without claiming an export');
    share.overrideShare = (params) {
      share.shared.add(params);
      return Future.value(const ShareResult('', ShareResultStatus.dismissed));
    };
    await _openFileLibrary(library);
    await _confirmExport(library);
    expect(share.shared, hasLength(1));
    spot<SnackBar>().doesNotExist();
    _expectNoExportSuccess();
  }

  Future<void> rejectPickerFailure(LibraryFile library) async {
    logEvent('Report a native picker exception without changing the library');
    var calls = 0;
    files.overrideOpenFile = ({acceptedTypeGroups, initialDirectory, confirmButtonText}) {
      calls++;
      expect(acceptedTypeGroups!.single.extensions, ['json']);
      return Future<XFile?>.error(PlatformException(code: 'picker_failed', message: 'Picker unavailable'));
    };
    await _openFileLibrary(library);
    final parsers = List.of(controller.parsers);
    final catalog = List.of(controller.catalog);
    await tapLabel('Import');
    expect(calls, 1);
    spot<Dialog>().doesNotExist();
    spot<SnackBar>()
        .spotText('Import failed: PlatformException(picker_failed, Picker unavailable, null, null)', exact: true)
        .existsOnce();
    expect(controller.parsers, parsers);
    expect(controller.catalog, catalog);
  }

  Future<void> cancelFilePicker(LibraryFile library) async {
    await _openFileLibrary(library);
    logEvent('Cancel the file picker without opening a selection or reporting an error');
    files.overrideOpenFile = ({acceptedTypeGroups, initialDirectory, confirmButtonText}) => Future.value();
    await tapLabel('Import');
    spot<Dialog>().doesNotExist();
    spot<SnackBar>().doesNotExist();
  }

  Future<void> rejectDesktopSaveFailure() async {
    var calls = 0;
    files.overrideGetSaveLocation = ({acceptedTypeGroups, options = const SaveDialogOptions()}) {
      calls++;
      expect(options.suggestedName, parserFileName);
      return Future<FileSaveLocation?>.error(PlatformException(code: 'save_failed', message: 'Save unavailable'));
    };
    await _openFileLibrary(LibraryFile.parsers);
    await _confirmExport(LibraryFile.parsers);
    expect(calls, 1);
    spot<SnackBar>()
        .spotText('Export failed: PlatformException(save_failed, Save unavailable, null, null)', exact: true)
        .existsOnce();
    _expectNoExportSuccess();
  }

  Future<void> cancelDesktopSave() async {
    var calls = 0;
    files.overrideGetSaveLocation = ({acceptedTypeGroups, options = const SaveDialogOptions()}) {
      calls++;
      return Future.value();
    };
    await _openFileLibrary(LibraryFile.parsers);
    await _confirmExport(LibraryFile.parsers);
    expect(calls, 1);
    expect(share.shared, isEmpty);
    spot<SnackBar>().doesNotExist();
  }
}
