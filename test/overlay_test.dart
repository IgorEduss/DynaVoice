import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dynavoice/overlay.dart';
import 'package:dynavoice/services/speech_recognition_service.dart';

import 'fakes/fake_speech_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Overlay envia transcrição real para revisão e fecha', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const messageChannel = BasicMessageChannel<Object?>(
      'x-slayer/overlay_messenger',
      JSONMessageCodec(),
    );
    const methodChannel = MethodChannel('x-slayer/overlay_channel');
    Object? shared;
    var closed = false;
    messenger.setMockDecodedMessageHandler<Object?>(messageChannel, (
      message,
    ) async {
      shared = message;
      return message;
    });
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'closeOverlay') closed = true;
      return true;
    });
    addTearDown(() {
      messenger.setMockDecodedMessageHandler<Object?>(messageChannel, null);
      messenger.setMockMethodCallHandler(methodChannel, null);
    });

    final speech = FakeSpeechRecognitionService();
    await tester.pumpWidget(DynaVoiceOverlayApp(speechService: speech));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('overlay_iniciar_voz')));
    await tester.pump();
    expect(speech.current.state, SpeechCaptureState.listening);
    const transcript =
        'Flexão do joelho direito, trinta e dois vírgula quatro quilos-força.';
    speech.complete(transcript);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('overlay_revisar')));
    await tester.tap(find.byKey(const Key('overlay_revisar')));
    await tester.pumpAndSettle();

    expect(shared, 'voice:$transcript');
    expect(closed, isTrue);
  });

  testWidgets('Cancelar no overlay não compartilha transcrição', (
    tester,
  ) async {
    final speech = FakeSpeechRecognitionService();
    await tester.pumpWidget(DynaVoiceOverlayApp(speechService: speech));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('overlay_iniciar_voz')));
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(speech.current.state, SpeechCaptureState.cancelled);
    expect(find.byKey(const Key('overlay_revisar')), findsNothing);
  });
}
