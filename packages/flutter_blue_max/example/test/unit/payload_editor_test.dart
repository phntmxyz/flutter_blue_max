import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/shared/payload_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

void main() {
  testWidgets('the payload editor blocks a second send and locks both inputs until completion', (tester) async {
    final release = Completer<void>();
    final sent = <List<int>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayloadEditor(
            onSend: (bytes) {
              sent.add(bytes);
              return release.future;
            },
          ),
        ),
      ),
    );
    final payload = spot<TextField>()..existsOnce();
    final encoding = spot<SegmentedButton<bool>>()..existsOnce();
    await act.enterText(payload, '01 02');
    await tester.pump();
    await act.tap(spotText('Send payload'));
    await tester.pump();
    try {
      final sending = spot<FilledButton>().withChild(spotText('Sending…', exact: true))..existsOnce();
      expect(payload.snapshotWidget().readOnly, isTrue);
      expect(encoding.snapshotWidget().onSelectionChanged, isNull);
      expect(sending.snapshotWidget().onPressed, isNull);
      expect(sent, [
        [1, 2],
      ]);
    } finally {
      release.complete();
    }
    await tester.pumpAndSettle();
    expect(payload.snapshotWidget().readOnly, isFalse);
    expect(encoding.snapshotWidget().onSelectionChanged, isNotNull);
    final ready = spot<FilledButton>().withChild(spotText('Send payload', exact: true))..existsOnce();
    expect(ready.snapshotWidget().onPressed, isNotNull);
    expect(sent, hasLength(1));
  });

  testWidgets('encoding changes revalidate a touched payload before sending', (tester) async {
    final sent = <List<int>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayloadEditor(
            onSend: (bytes) async {
              sent.add(bytes);
            },
          ),
        ),
      ),
    );
    final payload = spot<TextField>()..existsOnce();
    await act.enterText(payload, 'F');
    await tester.pumpAndSettle();
    await act.tap(spotText('Send payload'));
    await tester.pumpAndSettle();
    spotText('Use complete hex byte pairs, such as 01 A2 FF.').existsOnce();
    expect(sent, isEmpty);

    await act.tap(spotText('UTF-8'));
    await tester.pumpAndSettle();
    spotText('Use complete hex byte pairs, such as 01 A2 FF.').doesNotExist();
    await act.tap(spotText('Send payload'));
    await tester.pumpAndSettle();
    expect(sent, [
      [70],
    ]);

    await act.tap(spotText('Hex', exact: true));
    await tester.pumpAndSettle();
    spotText('Use complete hex byte pairs, such as 01 A2 FF.').existsOnce();
    await act.tap(spotText('Send payload'));
    await tester.pumpAndSettle();
    expect(sent, hasLength(1));
  });
}
