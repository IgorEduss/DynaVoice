import 'dart:async';

import 'package:dynavoice/services/speech_recognition_service.dart';

class FakeSpeechRecognitionService implements SpeechRecognitionService {
  final _controller = StreamController<SpeechCaptureSnapshot>.broadcast();
  SpeechCaptureSnapshot _current = const SpeechCaptureSnapshot(
    SpeechCaptureState.permissionRequired,
  );

  @override
  SpeechCaptureSnapshot get current => _current;

  @override
  Stream<SpeechCaptureSnapshot> get snapshots => _controller.stream;

  void emit(SpeechCaptureSnapshot snapshot) {
    _current = snapshot;
    _controller.add(snapshot);
  }

  void complete(String transcript) => emit(
    SpeechCaptureSnapshot(
      SpeechCaptureState.result,
      transcript: transcript,
      message: 'Transcrição concluída. Revise antes de salvar.',
      isFinal: true,
    ),
  );

  @override
  Future<void> prepare() async => emit(
    const SpeechCaptureSnapshot(
      SpeechCaptureState.ready,
      message: 'Pronto para ouvir em português brasileiro.',
    ),
  );

  @override
  Future<void> start() async => emit(
    const SpeechCaptureSnapshot(
      SpeechCaptureState.listening,
      message: 'Ouvindo… fale uma medição.',
    ),
  );

  @override
  Future<void> stop() async => emit(
    SpeechCaptureSnapshot(
      SpeechCaptureState.processing,
      transcript: current.transcript,
      message: 'Processando a transcrição…',
    ),
  );

  @override
  Future<void> cancel() async => emit(
    const SpeechCaptureSnapshot(
      SpeechCaptureState.cancelled,
      message: 'Captura cancelada. Nenhuma medição foi criada.',
    ),
  );

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
