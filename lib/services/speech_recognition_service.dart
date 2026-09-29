import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechCaptureState {
  permissionRequired,
  ready,
  listening,
  processing,
  result,
  cancelled,
  error,
  unavailable,
}

class SpeechCaptureSnapshot {
  final SpeechCaptureState state;
  final String transcript;
  final String? message;
  final bool isFinal;

  const SpeechCaptureSnapshot(
    this.state, {
    this.transcript = '',
    this.message,
    this.isFinal = false,
  });
}

abstract class SpeechRecognitionService {
  Stream<SpeechCaptureSnapshot> get snapshots;

  SpeechCaptureSnapshot get current;

  Future<void> prepare();

  Future<void> start();

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class DeviceSpeechRecognitionService implements SpeechRecognitionService {
  DeviceSpeechRecognitionService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  static const localeId = 'pt_BR';

  final SpeechToText _speech;
  final _controller = StreamController<SpeechCaptureSnapshot>.broadcast();
  SpeechCaptureSnapshot _current = const SpeechCaptureSnapshot(
    SpeechCaptureState.permissionRequired,
    message: 'Permita o uso do microfone para ditar uma medição.',
  );
  bool _initialized = false;
  bool _disposed = false;
  bool _cancelledByUser = false;
  String _latestTranscript = '';

  @override
  Stream<SpeechCaptureSnapshot> get snapshots => _controller.stream;

  @override
  SpeechCaptureSnapshot get current => _current;

  void _emit(SpeechCaptureSnapshot value) {
    if (_disposed) return;
    _current = value;
    _controller.add(value);
  }

  @override
  Future<void> prepare() async {
    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      _emit(
        const SpeechCaptureSnapshot(
          SpeechCaptureState.permissionRequired,
          message: 'Permita o uso do microfone para ditar uma medição.',
        ),
      );
      return;
    }
    await _initializeRecognizer();
  }

  Future<bool> _initializeRecognizer() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (!_initialized) {
        final hasPermission = await _speech.hasPermission;
        _emit(
          SpeechCaptureSnapshot(
            hasPermission
                ? SpeechCaptureState.unavailable
                : SpeechCaptureState.permissionRequired,
            message: hasPermission
                ? 'O reconhecimento de fala não está disponível neste aparelho.'
                : 'A permissão do microfone foi negada. Ative-a nas configurações do Android.',
          ),
        );
        return false;
      }
      final locales = await _speech.locales();
      if (!locales.any(
        (locale) =>
            locale.localeId.toLowerCase().replaceAll('-', '_') ==
            localeId.toLowerCase(),
      )) {
        _emit(
          const SpeechCaptureSnapshot(
            SpeechCaptureState.unavailable,
            message:
                'O reconhecedor instalado não oferece português brasileiro (pt-BR).',
          ),
        );
        return false;
      }
      _emit(
        const SpeechCaptureSnapshot(
          SpeechCaptureState.ready,
          message: 'Pronto para ouvir em português brasileiro.',
        ),
      );
      return true;
    } catch (error) {
      _emit(
        SpeechCaptureSnapshot(
          SpeechCaptureState.error,
          message: 'Falha ao preparar o reconhecimento: $error',
        ),
      );
      return false;
    }
  }

  @override
  Future<void> start() async {
    _cancelledByUser = false;
    _latestTranscript = '';
    if (!await _initializeRecognizer()) return;
    try {
      _emit(
        const SpeechCaptureSnapshot(
          SpeechCaptureState.listening,
          message: 'Ouvindo… fale uma medição.',
        ),
      );
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      _emit(
        SpeechCaptureSnapshot(
          SpeechCaptureState.error,
          message: 'Não foi possível iniciar a escuta: $error',
        ),
      );
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _latestTranscript = result.recognizedWords.trim();
    if (result.finalResult) {
      if (_latestTranscript.isEmpty) {
        _emit(
          const SpeechCaptureSnapshot(
            SpeechCaptureState.error,
            message: 'Nenhuma fala foi reconhecida. Tente novamente.',
          ),
        );
      } else {
        _emit(
          SpeechCaptureSnapshot(
            SpeechCaptureState.result,
            transcript: _latestTranscript,
            message: 'Transcrição concluída. Revise antes de salvar.',
            isFinal: true,
          ),
        );
      }
      return;
    }
    _emit(
      SpeechCaptureSnapshot(
        SpeechCaptureState.listening,
        transcript: _latestTranscript,
        message: 'Ouvindo… resultado parcial.',
      ),
    );
  }

  void _onStatus(String status) {
    if (_cancelledByUser) return;
    if (status == SpeechToText.doneStatus &&
        _current.state == SpeechCaptureState.listening) {
      _emit(
        SpeechCaptureSnapshot(
          SpeechCaptureState.processing,
          transcript: _latestTranscript,
          message: 'Processando a transcrição…',
        ),
      );
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (_cancelledByUser) return;
    final permissionError = error.errorMsg == 'error_permission';
    _emit(
      SpeechCaptureSnapshot(
        permissionError
            ? SpeechCaptureState.permissionRequired
            : SpeechCaptureState.error,
        transcript: _latestTranscript,
        message: permissionError
            ? 'O Android não autorizou o uso do microfone.'
            : _friendlyError(error.errorMsg),
      ),
    );
  }

  String _friendlyError(String code) => switch (code) {
    'error_no_match' => 'A fala não pôde ser transcrita. Tente novamente.',
    'error_speech_timeout' => 'Nenhuma fala foi detectada a tempo.',
    'error_network' ||
    'error_network_timeout' => 'O serviço de reconhecimento está sem conexão.',
    'error_language_not_supported' || 'error_language_unavailable' =>
      'Português brasileiro não está disponível no reconhecedor.',
    'error_busy' => 'O reconhecedor está ocupado. Aguarde e tente novamente.',
    _ => 'Falha no reconhecimento de fala ($code).',
  };

  @override
  Future<void> stop() async {
    if (!_initialized || !_speech.isListening) return;
    _emit(
      SpeechCaptureSnapshot(
        SpeechCaptureState.processing,
        transcript: _latestTranscript,
        message: 'Processando a transcrição…',
      ),
    );
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _cancelledByUser = true;
    if (_initialized) await _speech.cancel();
    _latestTranscript = '';
    _emit(
      const SpeechCaptureSnapshot(
        SpeechCaptureState.cancelled,
        message: 'Captura cancelada. Nenhuma medição foi criada.',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_initialized && _speech.isListening) await _speech.cancel();
    _disposed = true;
    await _controller.close();
  }
}

class UnavailableSpeechRecognitionService implements SpeechRecognitionService {
  final _controller = StreamController<SpeechCaptureSnapshot>.broadcast();
  final SpeechCaptureSnapshot _snapshot;

  UnavailableSpeechRecognitionService({
    String message = 'Reconhecimento de fala disponível somente no Android.',
  }) : _snapshot = SpeechCaptureSnapshot(
         SpeechCaptureState.unavailable,
         message: message,
       );

  @override
  SpeechCaptureSnapshot get current => _snapshot;

  @override
  Stream<SpeechCaptureSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> prepare() async => _controller.add(_snapshot);

  @override
  Future<void> start() async => _controller.add(_snapshot);

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() => _controller.close();
}
