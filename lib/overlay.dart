import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'parser_service.dart';
import 'services/overlay_message_bridge.dart';

/// The floating view communicates with the active session in the main engine.
abstract class FloatingVoiceBridge {
  Stream<dynamic> get messages;
  void send(Map<String, Object?> message);
  Future<void> resize({required bool expanded});
}

class DeviceFloatingVoiceBridge implements FloatingVoiceBridge {
  @override
  Stream<dynamic> get messages => OverlayMessageBridge.messages;

  @override
  void send(Map<String, Object?> message) {
    OverlayMessageBridge.send(message);
  }

  @override
  Future<void> resize({required bool expanded}) async {
    await FlutterOverlayWindow.updateFlag(
      expanded ? OverlayFlag.focusPointer : OverlayFlag.defaultFlag,
    );
    await FlutterOverlayWindow.resizeOverlay(
      expanded ? 320 : 80,
      expanded ? 500 : 80,
      !expanded,
    );
  }
}

class DynaVoiceOverlayApp extends StatelessWidget {
  const DynaVoiceOverlayApp({super.key, this.bridge});
  final FloatingVoiceBridge? bridge;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
    ),
    home: VoiceOverlay(bridge: bridge),
  );
}

enum _BubbleState { idle, waiting, listening, processing, review, error, saved }

class VoiceOverlay extends StatefulWidget {
  const VoiceOverlay({super.key, this.bridge});
  final FloatingVoiceBridge? bridge;

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<VoiceOverlay> {
  late final FloatingVoiceBridge _bridge;
  StreamSubscription<dynamic>? _subscription;
  Timer? _timeout;
  _BubbleState _state = _BubbleState.idle;
  bool _expanded = false;
  bool _saving = false;
  Map<dynamic, dynamic> _draft = {};
  String _message = '';
  String? _joint, _movement, _side;
  final _force = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bridge = widget.bridge ?? DeviceFloatingVoiceBridge();
    _subscription = _bridge.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _subscription?.cancel();
    _force.dispose();
    super.dispose();
  }

  void _send(String action, [Map<String, Object?> extra = const {}]) {
    _bridge.send({'source': 'overlay', 'action': action, ...extra});
  }

  Future<void> _setExpanded(bool expanded) async {
    if (!expanded) FocusManager.instance.primaryFocus?.unfocus();
    try {
      await _bridge
          .resize(expanded: expanded)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Keep the assistant usable even if the window could not be resized.
    }
    if (mounted) setState(() => _expanded = expanded);
  }

  void _onMessage(dynamic value) {
    if (!mounted || value is! Map) return;
    final type = value['type'];
    if (type == 'status') {
      _timeout?.cancel();
      final state = value['state'];
      if (state == 'listening' || state == 'processing') {
        setState(() {
          _state = state == 'listening'
              ? _BubbleState.listening
              : _BubbleState.processing;
        });
      } else if (state == 'error' ||
          state == 'unavailable' ||
          state == 'permissionRequired') {
        _showError(value['message']?.toString() ?? 'Não foi possível ditar.');
      }
    } else if (type == 'review') {
      _timeout?.cancel();
      final joint = value['joint'];
      final movement = value['movement'];
      final side = value['side'];
      final force = value['force'];
      _force.text = force is num
          ? (force == force.roundToDouble()
                ? force.toInt().toString()
                : '$force')
          : '';
      setState(() {
        _draft = value;
        _joint = ParserService.articulacoes.contains(joint)
            ? joint as String
            : null;
        _movement = ParserService.movimentos.contains(movement)
            ? movement as String
            : null;
        _side = ParserService.lados.contains(side) ? side as String : null;
        _message = '';
        _state = _BubbleState.review;
        _saving = false;
      });
      unawaited(_setExpanded(true));
    } else if (type == 'saved') {
      _timeout?.cancel();
      setState(() {
        _state = _BubbleState.saved;
        _saving = false;
        _draft = {};
      });
      unawaited(_setExpanded(false));
      _timeout = Timer(const Duration(seconds: 2), () {
        if (mounted && _state == _BubbleState.saved) {
          setState(() => _state = _BubbleState.idle);
        }
      });
    } else if (type == 'idle') {
      _timeout?.cancel();
      setState(() {
        _state = _BubbleState.idle;
        _saving = false;
        _draft = {};
      });
      unawaited(_setExpanded(false));
    } else if (type == 'error') {
      _showError(value['message']?.toString() ?? 'Não foi possível continuar.');
    } else if (type == 'validation') {
      _timeout?.cancel();
      setState(() {
        _saving = false;
        _message = value['message']?.toString() ?? 'Confira os dados.';
      });
    }
  }

  void _showError(String message) {
    _timeout?.cancel();
    if (!mounted) return;
    setState(() {
      _state = _BubbleState.error;
      _message = message;
      _saving = false;
    });
    unawaited(_setExpanded(true));
  }

  void _start() {
    _timeout?.cancel();
    setState(() {
      _state = _BubbleState.waiting;
      _draft = {};
      _saving = false;
    });
    if (_expanded) unawaited(_setExpanded(false));
    _send('start');
    _timeout = Timer(const Duration(seconds: 8), () {
      if (mounted && _state == _BubbleState.waiting) {
        _showError('A sessão não respondeu. Abra novamente o DynaVoice.');
      }
    });
  }

  void _cancel() {
    _timeout?.cancel();
    _send('cancel');
    setState(() {
      _state = _BubbleState.idle;
      _draft = {};
      _saving = false;
    });
    unawaited(_setExpanded(false));
  }

  void _confirm() {
    final force = double.tryParse(_force.text.trim().replaceAll(',', '.'));
    if (_saving || !_canConfirm || force == null) return;
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    _send('confirm', {
      'draftId': _draft['draftId'],
      'values': {
        'joint': _joint,
        'movement': _movement,
        'side': _side,
        'force': force,
      },
    });
    _timeout = Timer(const Duration(seconds: 8), () {
      if (mounted && _saving) {
        _showError(
          'Não foi possível confirmar. Confira o histórico antes de repetir.',
        );
      }
    });
  }

  bool get _canConfirm {
    final force = double.tryParse(_force.text.trim().replaceAll(',', '.'));
    return ParserService.articulacoes.contains(_joint) &&
        ParserService.movimentos.contains(_movement) &&
        ParserService.lados.contains(_side) &&
        force != null &&
        force.isFinite &&
        force >= 0 &&
        force <= 1000;
  }

  void _onBubbleTap() {
    if (_state == _BubbleState.listening) {
      _send('stop');
    } else if (_state != _BubbleState.waiting &&
        _state != _BubbleState.processing) {
      _start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: _expanded ? _panel() : _bubble(),
  );

  Widget _bubble() {
    final listening = _state == _BubbleState.listening;
    final saving = _state == _BubbleState.saved;
    return Center(
      child: Semantics(
        button: true,
        label: listening ? 'Concluir ditado' : 'Ditar medição',
        child: GestureDetector(
          key: const Key('overlay_microfone'),
          onTap: _onBubbleTap,
          onLongPress: () => unawaited(_setExpanded(true)),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: saving
                  ? const Color(0xFF237A55)
                  : listening
                  ? const Color(0xFFB34545)
                  : const Color(0xFF176B87),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              saving
                  ? Icons.check
                  : listening
                  ? Icons.stop
                  : Icons.mic,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    final review = _state == _BubbleState.review;
    final error = _state == _BubbleState.error;
    final warnings = (_draft['warnings'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();

    return Material(
      color: Colors.transparent,
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review
                      ? 'Conferir medição'
                      : error
                      ? 'Atenção'
                      : 'DynaVoice',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (review) ...[
                  Text(_draft['transcript']?.toString() ?? ''),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('overlay_joint_${_draft['draftId']}'),
                    initialValue: _joint,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Articulação',
                      isDense: true,
                    ),
                    items: ParserService.articulacoes
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _joint = v),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('overlay_movement_${_draft['draftId']}'),
                    initialValue: _movement,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Movimento',
                      isDense: true,
                    ),
                    items: ParserService.movimentos
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _movement = v),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('overlay_side_${_draft['draftId']}'),
                    initialValue: _side,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lado',
                      isDense: true,
                    ),
                    items: ParserService.lados
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _side = v),
                  ),
                  TextFormField(
                    key: const Key('overlay_force'),
                    controller: _force,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Força (kgf)',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reconhecimento inicial: ${warnings.join(' ')}',
                      style: const TextStyle(color: Color(0xFF9B3030)),
                    ),
                  ],
                  if (!_canConfirm)
                    const Text(
                      'Preencha todos os campos e informe força de 0 a 1000 kgf.',
                    ),
                  if (_message.isNotEmpty)
                    Text(
                      _message,
                      style: const TextStyle(color: Color(0xFF9B3030)),
                    ),
                ] else
                  Text(
                    error
                        ? _message
                        : 'Toque no microfone para ditar uma medição.',
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (review)
                      FilledButton(
                        key: const Key('overlay_confirmar'),
                        onPressed: _saving || !_canConfirm ? null : _confirm,
                        child: Text(_saving ? 'Salvando...' : 'Confirmar'),
                      ),
                    if (review || error)
                      OutlinedButton(
                        onPressed: _saving ? null : _start,
                        child: const Text('Repetir'),
                      ),
                    TextButton(
                      onPressed: _saving ? null : _cancel,
                      child: const Text('Fechar'),
                    ),
                    if (!review && !error)
                      TextButton(
                        onPressed: () => _send('close'),
                        child: const Text('Encerrar assistente'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
