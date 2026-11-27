import 'dart:async';

import 'package:dynavoice/overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFloatingBridge implements FloatingVoiceBridge {
  final controller = StreamController<dynamic>.broadcast();
  final sent = <Map<String, Object?>>[];
  final sizes = <bool>[];

  @override
  Stream<dynamic> get messages => controller.stream;
  @override
  void send(Map<String, Object?> message) => sent.add(message);
  @override
  Future<void> resize({required bool expanded}) async => sizes.add(expanded);
}

void main() {
  testWidgets('Bolha inicia ditado e exige confirmação da medição', (
    tester,
  ) async {
    final bridge = FakeFloatingBridge();
    addTearDown(bridge.controller.close);
    await tester.pumpWidget(DynaVoiceOverlayApp(bridge: bridge));
    expect(find.byKey(const Key('overlay_microfone')), findsOneWidget);
    expect(find.byKey(const Key('overlay_confirmar')), findsNothing);

    await tester.tap(find.byKey(const Key('overlay_microfone')));
    expect(bridge.sent.last['action'], 'start');
    bridge.controller.add({'type': 'status', 'state': 'listening'});
    await tester.pump();
    expect(find.byIcon(Icons.stop), findsOneWidget);

    bridge.controller.add({
      'type': 'review',
      'draftId': 7,
      'transcript': 'Flexão de joelho direito 45',
      'joint': 'Joelho',
      'movement': 'Flexão',
      'side': 'Direito',
      'force': 45.0,
      'warnings': <String>[],
      'valid': true,
    });
    await tester.pumpAndSettle();
    expect(bridge.sizes.last, isTrue);
    expect(find.text('Joelho'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('overlay_force')), '48,5');
    await tester.ensureVisible(find.byKey(const Key('overlay_confirmar')));
    await tester.tap(find.byKey(const Key('overlay_confirmar')));
    await tester.pump();
    expect(bridge.sent.last['action'], 'confirm');
    expect(bridge.sent.last['draftId'], 7);
    expect((bridge.sent.last['values'] as Map)['force'], 48.5);
    bridge.controller.add({'type': 'saved'});
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(bridge.sizes.last, isFalse);
    expect(find.byKey(const Key('overlay_microfone')), findsOneWidget);
  });

  testWidgets('Medição incompleta não pode ser confirmada', (tester) async {
    final bridge = FakeFloatingBridge();
    addTearDown(bridge.controller.close);
    await tester.pumpWidget(DynaVoiceOverlayApp(bridge: bridge));
    bridge.controller.add({
      'type': 'review',
      'draftId': 1,
      'transcript': 'Joelho direito',
      'joint': 'Joelho',
      'movement': '',
      'side': 'Direito',
      'force': null,
      'warnings': ['Informe força válida.'],
      'valid': false,
    });
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('overlay_confirmar')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Preencha todos os campos e informe força de 0 a 1000 kgf.'),
      findsOneWidget,
    );
    expect(bridge.sent.where((m) => m['action'] == 'confirm'), isEmpty);
  });
}
