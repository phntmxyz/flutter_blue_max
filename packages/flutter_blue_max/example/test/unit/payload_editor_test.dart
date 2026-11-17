import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/shared/payload_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';

void main() {
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
