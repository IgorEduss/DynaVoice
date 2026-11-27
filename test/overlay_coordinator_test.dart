import 'package:dynavoice/parser_service.dart';
import 'package:dynavoice/services/overlay_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_speech_recognition_service.dart';

void main() {
  test('Apenas uma confirmação válida grava a captura da bolha', () async {
    final speech = FakeSpeechRecognitionService();
    addTearDown(speech.dispose);
    final events = <Map<String, Object?>>[];
    final saved = <DadosAfericao>[];
    final coordinator = OverlayCoordinator(
      speech: speech,
      sessionId: () => 5,
      save: (session, data) async {
        expect(session, 5);
        saved.add(data);
      },
      send: events.add,
      close: () async {},
    );
    final subscription = speech.snapshots.listen(coordinator.handleSpeech);
    addTearDown(subscription.cancel);

    await coordinator.handle({'source': 'overlay', 'action': 'start'});
    speech.complete('flexão de joelho direito 45 kg força');
    await Future<void>.delayed(Duration.zero);
    final draft = events.lastWhere((event) => event['type'] == 'review');
    expect(draft['valid'], isTrue);
    expect(saved, isEmpty);

    final confirmation = {
      'source': 'overlay',
      'action': 'confirm',
      'draftId': draft['draftId'],
      'values': {
        'joint': 'Joelho',
        'movement': 'Flexão',
        'side': 'Direito',
        'force': 48.5,
      },
    };
    await coordinator.handle(confirmation);
    await coordinator.handle(confirmation);
    expect(saved, hasLength(1));
    expect(saved.single.articulacao, 'Joelho');
    expect(saved.single.lado, 'Direito');
    expect(saved.single.forca, 48.5);
    expect(saved.single.textoOriginal, 'flexão de joelho direito 45 kg força');
    expect(events.last['type'], 'saved');
  });

  test('Captura incompleta ou sem sessão não é gravada', () async {
    final speech = FakeSpeechRecognitionService();
    addTearDown(speech.dispose);
    final events = <Map<String, Object?>>[];
    var session = 5;
    var saved = 0;
    final coordinator = OverlayCoordinator(
      speech: speech,
      sessionId: () => session == 0 ? null : session,
      save: (_, _) async => saved++,
      send: events.add,
      close: () async {},
    );
    final subscription = speech.snapshots.listen(coordinator.handleSpeech);
    addTearDown(subscription.cancel);
    await coordinator.handle({'source': 'overlay', 'action': 'start'});
    speech.complete('joelho direito');
    await Future<void>.delayed(Duration.zero);
    final draft = events.lastWhere((event) => event['type'] == 'review');
    expect(draft['valid'], isFalse);
    await coordinator.handle({
      'source': 'overlay',
      'action': 'confirm',
      'draftId': draft['draftId'],
      'values': {
        'joint': 'Joelho',
        'movement': '',
        'side': 'Direito',
        'force': 0,
      },
    });
    expect(saved, 0);
    await coordinator.handle({'source': 'overlay', 'action': 'cancel'});
    session = 0;
    await coordinator.handle({'source': 'overlay', 'action': 'start'});
    expect(events.last['type'], 'error');
    expect(saved, 0);
  });

  test(
    'Uma captura incompleta pode ser corrigida antes da confirmação',
    () async {
      final speech = FakeSpeechRecognitionService();
      addTearDown(speech.dispose);
      final events = <Map<String, Object?>>[];
      final saved = <DadosAfericao>[];
      final coordinator = OverlayCoordinator(
        speech: speech,
        sessionId: () => 3,
        save: (_, data) async => saved.add(data),
        send: events.add,
        close: () async {},
      );
      final subscription = speech.snapshots.listen(coordinator.handleSpeech);
      addTearDown(subscription.cancel);
      await coordinator.handle({'source': 'overlay', 'action': 'start'});
      speech.complete('joelho direito');
      await Future<void>.delayed(Duration.zero);
      final draft = events.lastWhere((event) => event['type'] == 'review');
      await coordinator.handle({
        'source': 'overlay',
        'action': 'confirm',
        'draftId': draft['draftId'],
        'values': {
          'joint': 'Joelho',
          'movement': 'Flexão',
          'side': 'Direito',
          'force': -10,
        },
      });
      expect(events.last['type'], 'validation');
      expect(saved, isEmpty);
      await coordinator.handle({
        'source': 'overlay',
        'action': 'confirm',
        'draftId': draft['draftId'],
        'values': {
          'joint': 'Joelho',
          'movement': 'Flexão',
          'side': 'Direito',
          'force': 50,
        },
      });
      expect(saved.single.forca, 50);
      expect(saved.single.textoOriginal, 'joelho direito');
    },
  );
}
