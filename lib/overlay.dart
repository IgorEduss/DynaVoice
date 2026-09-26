import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Preserva a sobreposição do MVP original, com envio manual e identificação de simulação.
/// Nada é persistido pelo overlay: a tela principal exige revisão explícita.
class DynaVoiceOverlayApp extends StatelessWidget {
  const DynaVoiceOverlayApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: DemoOverlay());
}

class DemoOverlay extends StatefulWidget {
  const DemoOverlay({super.key});
  @override
  State<DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends State<DemoOverlay> {
  String _status =
      'Sem captura de áudio. Retorne ao app para revisar e salvar.';
  bool _sending = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DynaVoice • SIMULAÇÃO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_status),
              FilledButton(
                onPressed: _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        try {
                          await FlutterOverlayWindow.shareData(
                            'demo:Flexão de joelho direito trinta e dois vírgula quatro',
                          );
                          if (mounted) {
                            setState(
                              () => _status =
                                  'Exemplo enviado. Retorne ao DynaVoice para revisar. Nada foi salvo automaticamente.',
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _status =
                                  'Falha no envio. Retorne ao aplicativo.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                child: const Text('Enviar exemplo'),
              ),
              TextButton(
                onPressed: () => FlutterOverlayWindow.closeOverlay(),
                child: const Text('Fechar demonstração'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
