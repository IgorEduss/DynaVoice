import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'services/speech_recognition_service.dart';

/// A sobreposição apenas captura e devolve a transcrição. A persistência
/// continua exclusiva da revisão obrigatória na tela principal.
class DynaVoiceOverlayApp extends StatelessWidget {
  final SpeechRecognitionService? speechService;

  const DynaVoiceOverlayApp({super.key, this.speechService});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: VoiceOverlay(speechService: speechService),
  );
}

class VoiceOverlay extends StatefulWidget {
  final SpeechRecognitionService? speechService;

  const VoiceOverlay({super.key, this.speechService});

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<VoiceOverlay> {
  late final SpeechRecognitionService _speech;
  late SpeechCaptureSnapshot _snapshot;
  StreamSubscription<SpeechCaptureSnapshot>? _subscription;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _speech = widget.speechService ?? DeviceSpeechRecognitionService();
    _snapshot = _speech.current;
    _subscription = _speech.snapshots.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
    unawaited(_speech.prepare());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_speech.dispose());
    super.dispose();
  }

  bool get _active =>
      _snapshot.state == SpeechCaptureState.listening ||
      _snapshot.state == SpeechCaptureState.processing;

  Future<void> _sendForReview() async {
    final transcript = _snapshot.transcript.trim();
    if (transcript.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await FlutterOverlayWindow.shareData('voice:$transcript');
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {
      if (mounted) {
        setState(
          () => _snapshot = SpeechCaptureSnapshot(
            SpeechCaptureState.error,
            transcript: transcript,
            message: 'Falha ao retornar a transcrição ao DynaVoice.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DynaVoice • VOZ pt-BR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(_snapshot.message ?? 'Preparando reconhecimento…'),
              if (_snapshot.transcript.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(
                  _snapshot.transcript,
                  key: const Key('overlay_transcricao'),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilledButton.icon(
                    key: const Key('overlay_iniciar_voz'),
                    onPressed: _active || _sending ? null : _speech.start,
                    icon: const Icon(Icons.mic),
                    label: const Text('Ditar'),
                  ),
                  if (_snapshot.state == SpeechCaptureState.listening)
                    OutlinedButton(
                      onPressed: _speech.stop,
                      child: const Text('Concluir'),
                    ),
                  if (_active)
                    TextButton(
                      onPressed: _speech.cancel,
                      child: const Text('Cancelar'),
                    ),
                  if (_snapshot.state == SpeechCaptureState.result)
                    FilledButton(
                      key: const Key('overlay_revisar'),
                      onPressed: _sending ? null : _sendForReview,
                      child: const Text('Revisar no DynaVoice'),
                    ),
                  TextButton(
                    onPressed: () async {
                      await _speech.cancel();
                      await FlutterOverlayWindow.closeOverlay();
                    },
                    child: const Text('Fechar'),
                  ),
                ],
              ),
              const Text(
                'Nada é salvo pela sobreposição. A confirmação ocorre no aplicativo.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
