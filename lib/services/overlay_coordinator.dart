import '../parser_service.dart';
import 'speech_recognition_service.dart';

/// Coordinates the floating assistant with the active session in the main app.
/// A measurement is persisted only after an explicit confirmation of the draft.
class OverlayCoordinator {
  OverlayCoordinator({
    required this.speech,
    required this.sessionId,
    required this.save,
    required this.send,
    required this.close,
  });

  final SpeechRecognitionService speech;
  final int? Function() sessionId;
  final Future<void> Function(int session, DadosAfericao data) save;
  final void Function(Map<String, Object?> event) send;
  final Future<void> Function() close;

  bool _ownsCapture = false;
  bool _saving = false;
  DadosAfericao? _draft;
  int _draftId = 0;

  bool handleSpeech(SpeechCaptureSnapshot snapshot) {
    if (!_ownsCapture) return false;
    if (snapshot.state == SpeechCaptureState.result &&
        snapshot.isFinal &&
        snapshot.transcript.trim().isNotEmpty) {
      final draft = ParserService.processarTextoTranscrito(snapshot.transcript);
      _draft = draft;
      _draftId++;
      send({
        'type': 'review',
        'draftId': _draftId,
        'transcript': snapshot.transcript,
        'joint': draft.articulacao,
        'movement': draft.movimento,
        'side': draft.lado,
        'force': draft.forca,
        'warnings': draft.alertas,
        'valid': draft.validar().isEmpty,
      });
    } else {
      send({
        'type': 'status',
        'state': snapshot.state.name,
        'message': snapshot.message,
        'transcript': snapshot.transcript,
      });
    }
    return true;
  }

  Future<void> handle(dynamic message) async {
    if (message is! Map || message['source'] != 'overlay') return;
    switch (message['action']) {
      case 'start':
        if (sessionId() == null) {
          send({'type': 'error', 'message': 'Inicie uma sessão no DynaVoice.'});
          return;
        }
        if (_saving ||
            speech.current.state == SpeechCaptureState.listening ||
            speech.current.state == SpeechCaptureState.processing) {
          send({'type': 'error', 'message': 'Aguarde a captura anterior.'});
          return;
        }
        _draft = null;
        _ownsCapture = true;
        try {
          await speech.start();
        } catch (_) {
          send({
            'type': 'error',
            'message': 'Não foi possível iniciar o ditado.',
          });
        }
      case 'stop':
        if (_ownsCapture) await speech.stop();
      case 'cancel':
        _draft = null;
        _ownsCapture = false;
        await speech.cancel();
        send({'type': 'idle'});
      case 'confirm':
        final session = sessionId();
        final draft = _draft;
        if (_saving ||
            draft == null ||
            session == null ||
            message['draftId'] != _draftId) {
          return;
        }
        final changes = message['values'];
        if (changes is! Map) {
          send({
            'type': 'validation',
            'message': 'Confira os dados antes de salvar.',
          });
          return;
        }
        final force = changes['force'];
        final corrected = DadosAfericao(
          articulacao: changes['joint'] is String
              ? changes['joint'] as String
              : '',
          movimento: changes['movement'] is String
              ? changes['movement'] as String
              : '',
          lado: changes['side'] is String ? changes['side'] as String : '',
          forca: force is num ? force.toDouble() : null,
          textoOriginal: draft.textoOriginal,
          registradaEm: draft.registradaEm,
        );
        final errors = corrected.validar();
        if (errors.isNotEmpty) {
          send({'type': 'validation', 'message': errors.join('\n')});
          return;
        }
        _saving = true;
        _draft = null;
        try {
          await save(session, corrected);
          _ownsCapture = false;
          send({'type': 'saved'});
        } catch (_) {
          _ownsCapture = false;
          send({
            'type': 'error',
            'message':
                'Não foi possível confirmar a gravação. Confira o histórico.',
          });
        } finally {
          _saving = false;
        }
      case 'close':
        _draft = null;
        _ownsCapture = false;
        await speech.cancel();
        await close();
    }
  }

  void reset() {
    _draft = null;
    _ownsCapture = false;
  }
}
