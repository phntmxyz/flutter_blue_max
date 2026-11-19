import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

/// Replaces the native file dialogs: opening returns [openContent], saving goes to [savePath].
final class FakeFileSelector() extends FileSelectorPlatform {
  /// What the next open dialog returns; null cancels it.
  String? openContent;

  /// Where the next save dialog saves; null cancels it.
  String? savePath;

  Future<XFile?> Function({List<XTypeGroup>? acceptedTypeGroups, String? initialDirectory, String? confirmButtonText})?
  overrideOpenFile;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final override = overrideOpenFile;
    if (override != null) {
      return await override(
        acceptedTypeGroups: acceptedTypeGroups,
        initialDirectory: initialDirectory,
        confirmButtonText: confirmButtonText,
      );
    }
    final content = openContent;
    return content == null ? null : XFile.fromData(utf8.encode(content), name: 'parsers.json');
  }

  Future<FileSaveLocation?> Function({List<XTypeGroup>? acceptedTypeGroups, SaveDialogOptions options})?
  overrideGetSaveLocation;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    final override = overrideGetSaveLocation;
    if (override != null) {
      return await override(acceptedTypeGroups: acceptedTypeGroups, options: options);
    }
    final path = savePath;
    return path == null ? null : FileSaveLocation(path);
  }
}
