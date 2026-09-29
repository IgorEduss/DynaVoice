import 'package:flutter_test/flutter_test.dart';
import 'package:dynavoice/services/speech_recognition_service.dart';

import 'fakes/fake_speech_recognition_service.dart';

void main() {
  test('Implementação falsa reproduz estados e resultado final', () async {
    final service = FakeSpeechRecognitionService();
    addTearDown(service.dispose);
    final states = <SpeechCaptureState>[];
    final subscription = service.snapshots.listen(
      (snapshot) => states.add(snapshot.state),
    );
    addTearDown(subscription.cancel);

    await service.prepare();
    await service.start();
    service.emit(
      const SpeechCaptureSnapshot(
        SpeechCaptureState.listening,
        transcript: 'flexão do joelho',
      ),
    );
    await service.stop();
    service.complete(
      'Flexão do joelho direito, trinta e dois vírgula quatro quilos-força.',
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      states,
      containsAllInOrder([
        SpeechCaptureState.ready,
        SpeechCaptureState.listening,
        SpeechCaptureState.processing,
        SpeechCaptureState.result,
      ]),
    );
    expect(service.current.isFinal, isTrue);
    expect(service.current.transcript, contains('trinta e dois'));
  });

  test('Cancelamento falso descarta a captura', () async {
    final service = FakeSpeechRecognitionService();
    addTearDown(service.dispose);
    await service.start();
    await service.cancel();
    expect(service.current.state, SpeechCaptureState.cancelled);
    expect(service.current.transcript, isEmpty);
  });
}
