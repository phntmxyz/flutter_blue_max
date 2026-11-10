import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

import 'workbench_robot.dart';

/// A parser that is not bundled, for import files.
const _ownParser = AdvertisementParser(
  name: 'Own sensor',
  source: AdvertisementSource.manufacturer,
  companyId: 0x1234,
  fields: [AdvertisementField('Level', 0, AdvertisementFieldType.uint8)],
);

/// Import, export and reset of the saved parsers in the Library tab.
extension ParserFilesRobot on WorkbenchRobot {
  Future<void> exportChosenThroughShareSheet() async {
    await tapLabel('Library');
    await tapLabel('Export');
    logEvent('Deselect all parsers, then choose one');
    await tapInDialog('All parsers');
    spotText('Export 0 parsers', exact: true).existsOnce();
    await tapInDialog('FBM sensor');
    await tapInDialog('Export 1 parser');
    logEvent('Verify that the share sheet received a file with only the chosen parser');
    final params = share.shared.single;
    expect(params.fileNameOverrides, [parserFileName]);
    final content = await tester.runAsync(() => params.files!.single.readAsString());
    expect([for (final parser in decodeParserFile(content!)) parser.name], ['FBM sensor']);
    spotText('Exported 1 parser', exact: true).existsOnce();
  }

  Future<void> exportAllToFile(Directory directory) async {
    final path = '${directory.path}/$parserFileName';
    files.savePath = path;
    await tapLabel('Library');
    await tapLabel('Export');
    await tapInDialog('Export ${testDongleParsers.length} parsers');
    logEvent('Wait until the file is written to where the save dialog chose');
    final exported = find.text('Exported ${testDongleParsers.length} parsers');
    for (var attempt = 0; attempt < 50 && exported.evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    spotText('Exported ${testDongleParsers.length} parsers', exact: true).existsOnce();
    final content = await tester.runAsync(File(path).readAsString);
    expect(jsonEncode(decodeParserFile(content!)), jsonEncode(testDongleParsers));
  }

  Future<void> importSkippingPresentParsers() async {
    logEvent('Pick a file with an own parser and a bundled one');
    files.openContent = encodeParserFile([_ownParser, testDongleParsers.first]);
    await tapLabel('Library');
    await tapLabel('Import');
    await tapInDialog('Import 2 parsers');
    spotText('Imported 1 parser, 1 was already present', exact: true).existsOnce();
    expect(controller.parsers.map((parser) => parser.name), [...testDongleParsers.map((p) => p.name), 'Own sensor']);
    spotText('Own sensor', exact: true).existsOnce();
  }

  Future<void> rejectFileWithoutParsers() async {
    logEvent('Pick a JSON file that holds something else');
    files.openContent = '{"services": []}';
    await tapLabel('Library');
    await tapLabel('Import');
    spot<Dialog>().doesNotExist();
    spotText('Import failed: The file holds no parsers.', exact: true).existsOnce();
    expect(controller.parsers, hasLength(testDongleParsers.length));
  }

  Future<void> resetToBundledParsers() async {
    files.openContent = encodeParserFile([_ownParser]);
    await tapLabel('Library');
    await tapLabel('Import');
    await tapInDialog('Import 1 parser');
    await tapLabel('Reset parsers');
    logEvent('Cancelling keeps the own parser');
    await tapInDialog('Cancel');
    expect(controller.parsers, hasLength(testDongleParsers.length + 1));
    await tapLabel('Reset parsers');
    await tapInDialog('Reset');
    expect(jsonEncode(controller.parsers), jsonEncode(testDongleParsers));
    spotText('Own sensor', exact: true).doesNotExist();
  }
}
