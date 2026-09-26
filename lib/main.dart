import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data/database.dart';
import 'parser_service.dart';
import 'services/export_service.dart';
import 'overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    DatabaseFactory factory = databaseFactory;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    final db = await DynaDatabase.open(
      factory,
      p.join(directory.path, 'dynavoice.db'),
    );
    runApp(DynaVoiceApp(database: db));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível abrir o banco local. Reinicie o aplicativo.\n$error',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DynaVoiceOverlayApp());
}

class DynaVoiceApp extends StatelessWidget {
  final DynaDatabase database;
  const DynaVoiceApp({super.key, required this.database});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DynaVoice',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
      scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFFF4F7FA),
      ),
    ),
    home: TelaPrincipal(database: database),
  );
}

class TelaPrincipal extends StatefulWidget {
  final DynaDatabase database;
  const TelaPrincipal({super.key, required this.database});
  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  List<Map<String, Object?>> _patients = [],
      _history = [],
      _stats = [],
      _open = [];
  int? _patientId, _sessionId;
  int _tab = 0;
  bool _loading = true, _busy = false, _reviewing = false;
  String _search = '';
  StreamSubscription<dynamic>? _overlay;
  final _command = TextEditingController();
  DynaDatabase get db => widget.database;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    if (Platform.isAndroid) {
      _overlay = FlutterOverlayWindow.overlayListener.listen((message) {
        if (message is String &&
            message.startsWith('demo:') &&
            _sessionId != null &&
            !_reviewing) {
          unawaited(_review(message.substring(5), origin: 'simulacao'));
        }
      });
    }
  }

  @override
  void dispose() {
    _overlay?.cancel();
    _command.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _refresh() async {
    try {
      final patients = await db.patients();
      final history = await db.history(patientId: _patientId);
      final stats = await db.stats(patientId: _patientId);
      final open = await db.openSessions();
      if (mounted) {
        setState(() {
          _patients = patients;
          _history = history;
          _stats = stats;
          _open = open;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _notice('Erro ao ler registros: $e');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (e) {
      _notice('Operação não concluída: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPatient() async {
    final c = TextEditingController();
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastrar paciente'),
        content: Form(
          key: form,
          child: TextFormField(
            key: const Key('nome_paciente'),
            controller: c,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Nome'),
            validator: (v) => (v?.trim().length ?? 0) < 2
                ? 'Informe pelo menos dois caracteres.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, c.text.trim());
              }
            },
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
    // Controllers in a route are released after its dismissal animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    c.dispose();
    if (name != null && mounted) {
      await _run(() async {
        _patientId = await db.addPatient(name);
      });
    }
  }

  Future<void> _start() => _run(() async {
    if (_patientId == null) return;
    _sessionId = await db.startSession(_patientId!);
    _notice('Sessão iniciada. Revise cada medição antes de salvar.');
  });
  Future<void> _end() => _run(() async {
    if (_sessionId == null) return;
    await db.endSession(_sessionId!);
    _sessionId = null;
    if (Platform.isAndroid) {
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
    }
    _notice('Sessão encerrada. Os registros permanecem no banco.');
  });
  Future<void> _review(String text, {String origin = 'manual'}) async {
    if (_sessionId == null || _reviewing) return;
    _reviewing = true;
    final data = ParserService.processarTextoTranscrito(text);
    final force = TextEditingController(text: data.forca?.toString() ?? '');
    final form = GlobalKey<FormState>();
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Revisar medição'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(text.isEmpty ? 'Entrada manual' : text),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const Key('articulacao'),
                      initialValue: data.articulacao.isEmpty
                          ? null
                          : data.articulacao,
                      decoration: const InputDecoration(
                        labelText: 'Articulação',
                      ),
                      items: ParserService.articulacoes
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => data.articulacao = v ?? '',
                      validator: (v) =>
                          v == null ? 'Selecione a articulação.' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('movimento'),
                      initialValue: data.movimento.isEmpty
                          ? null
                          : data.movimento,
                      decoration: const InputDecoration(labelText: 'Movimento'),
                      items: ParserService.movimentos
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => data.movimento = v ?? '',
                      validator: (v) =>
                          v == null ? 'Selecione o movimento.' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('lado'),
                      initialValue: data.lado.isEmpty ? null : data.lado,
                      decoration: const InputDecoration(labelText: 'Lado'),
                      items: ['Direito', 'Esquerdo']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => data.lado = v ?? '',
                      validator: (v) => v == null ? 'Selecione o lado.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('forca'),
                      controller: force,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Força (kgf)',
                        helperText: 'Faixa técnica do MVP: 0 a 1000 kgf.',
                      ),
                      validator: (v) {
                        final n = double.tryParse(
                          (v ?? '').replaceAll(',', '.'),
                        );
                        return n == null || !n.isFinite || n < 0 || n > 1000
                            ? 'Informe um número de 0 a 1000.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Confirme os dados antes de gravar. O texto original será preservado.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirmar_medicao'),
              onPressed: () {
                if (form.currentState!.validate()) {
                  data.forca = double.parse(force.text.replaceAll(',', '.'));
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Confirmar e salvar'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await _run(() async {
          await db.saveMeasurement(_sessionId!, data, origin: origin);
          _command.clear();
          _notice('Medição salva no banco local.');
        });
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      force.dispose();
      _reviewing = false;
    }
  }

  Future<void> _showOverlay() async {
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
        _notice('Autorize a sobreposição nas configurações e toque novamente.');
        return;
      }
      await FlutterOverlayWindow.showOverlay(
        height: 300,
        width: 340,
        enableDrag: true,
        alignment: OverlayAlignment.centerRight,
        overlayTitle: 'DynaVoice - demonstração',
        overlayContent: 'Simulação sem captura de áudio',
      );
    } catch (e) {
      _notice('Não foi possível abrir a demonstração: $e');
    }
  }

  Future<void> _export() => _run(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = await ExportService.save(
      db,
      Directory(p.join(dir.path, 'DynaVoice')),
      patientId: _patientId,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON salvo'),
        content: SelectableText(
          'Arquivo com os registros ${_patientId == null ? "de todos os pacientes" : "do paciente selecionado"}:\n${file.path}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          if (Platform.isAndroid)
            FilledButton(
              onPressed: () async {
                try {
                  await Share.shareXFiles([
                    XFile(file.path),
                  ], subject: 'DynaVoice - registros');
                } catch (e) {
                  _notice('Arquivo salvo, mas o compartilhamento falhou: $e');
                }
              },
              child: const Text('Compartilhar'),
            ),
        ],
      ),
    );
  });
  Future<void> _deletePatient() async {
    if (_patientId == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir paciente e registros?'),
        content: const Text(
          'Serão excluídas todas as sessões, avaliações e medições deste paciente. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(() async {
        await db.deletePatient(_patientId!);
        _patientId = null;
        _sessionId = null;
      });
    }
  }

  Widget _card(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  @override
  Widget build(BuildContext context) {
    final name = _patients
        .where((p) => p['id'] == _patientId)
        .firstOrNull?['nome'];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DynaVoice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Exportar JSON',
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Atendimento',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Resultados',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    _card(
                      const Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'MVP acadêmico • entrada manual e simulação\nReconhecimento de voz ainda não integrado. Use dados fictícios.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_patients.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('paciente_$_patientId'),
                          initialValue: _patientId,
                          decoration: const InputDecoration(
                            labelText: 'Paciente',
                            filled: true,
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Todos os pacientes'),
                            ),
                            ..._patients.map(
                              (p) => DropdownMenuItem(
                                value: p['id'] as int,
                                child: Text(p['nome'] as String),
                              ),
                            ),
                          ],
                          onChanged: _busy || _sessionId != null
                              ? null
                              : (v) {
                                  setState(() => _patientId = v);
                                  unawaited(_refresh());
                                },
                        ),
                      ),
                    if (_tab == 0) ...[
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sessionId == null
                                  ? 'Organize seu atendimento'
                                  : 'Sessão #$_sessionId • $name',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            if (_sessionId == null)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton.icon(
                                    key: const Key('novo_paciente'),
                                    onPressed: _busy ? null : _addPatient,
                                    icon: const Icon(Icons.person_add_alt),
                                    label: const Text('Novo paciente'),
                                  ),
                                  OutlinedButton.icon(
                                    key: const Key('iniciar_sessao'),
                                    onPressed: _busy || _patientId == null
                                        ? null
                                        : _start,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Iniciar sessão'),
                                  ),
                                  if (_patients.isEmpty)
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(db.seedDemo),
                                      child: const Text(
                                        'Carregar dados fictícios',
                                      ),
                                    ),
                                ],
                              )
                            else ...[
                              TextField(
                                key: const Key('comando'),
                                controller: _command,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Texto da medição',
                                  hintText: 'Flexão de joelho direito 32,4',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton(
                                    key: const Key('revisar'),
                                    onPressed: _busy
                                        ? null
                                        : () => _review(_command.text),
                                    child: const Text('Revisar medição'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _review(
                                            'Flexão de joelho direito trinta e dois vírgula quatro',
                                            origin: 'simulacao',
                                          ),
                                    child: const Text('Simular exemplo'),
                                  ),
                                  if (Platform.isAndroid)
                                    OutlinedButton(
                                      onPressed: _busy ? null : _showOverlay,
                                      child: const Text(
                                        'Abrir sobreposição demo',
                                      ),
                                    ),
                                  TextButton(
                                    key: const Key('encerrar_sessao'),
                                    onPressed: _busy ? null : _end,
                                    child: const Text('Encerrar sessão'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_sessionId == null && _open.isNotEmpty)
                        _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sessões abertas',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ..._open
                                  .where(
                                    (s) =>
                                        _patientId == null ||
                                        s['paciente_id'] == _patientId,
                                  )
                                  .map(
                                    (s) => ListTile(
                                      title: Text(
                                        '${s['nome']} • sessão ${s['id']}',
                                      ),
                                      subtitle: Text('${s['iniciada_em']}'),
                                      trailing: TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () {
                                                setState(() {
                                                  _patientId =
                                                      s['paciente_id'] as int;
                                                  _sessionId = s['id'] as int;
                                                });
                                                unawaited(_refresh());
                                              },
                                        child: const Text('Retomar'),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pacientes (${_patients.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Buscar paciente',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (v) =>
                                  setState(() => _search = v.toLowerCase()),
                            ),
                            ..._patients
                                .where(
                                  (p) => (p['nome'] as String)
                                      .toLowerCase()
                                      .contains(_search),
                                )
                                .map(
                                  (p) => ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline),
                                    ),
                                    title: Text(p['nome'] as String),
                                    subtitle: Text(
                                      '${p['sessoes']} sessão(ões)',
                                    ),
                                    selected: p['id'] == _patientId,
                                    onTap: _sessionId != null || _busy
                                        ? null
                                        : () {
                                            setState(
                                              () => _patientId = p['id'] as int,
                                            );
                                            unawaited(_refresh());
                                          },
                                  ),
                                ),
                            if (_patientId != null && _sessionId == null)
                              TextButton.icon(
                                onPressed: _busy ? null : _deletePatient,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text(
                                  'Excluir paciente selecionado',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_tab == 1) ...[
                      Text(
                        'Histórico • ${_history.length} medições',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (_history.isEmpty)
                        const Text('Nenhuma medição salva para este filtro.'),
                      ..._history.map(
                        (m) => _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m['forca_kgf']} kgf • ${m['articulacao']} / ${m['movimento']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${m['paciente']} • ${m['lado']} • sessão ${m['sessao_id']}',
                              ),
                              Text(
                                '${m['registrada_em']} • ${m['origem']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_tab == 2) ...[
                      Text(
                        'Resumo por avaliação e lado',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Resultados descritivos em kgf. Não constituem interpretação diagnóstica.',
                      ),
                      const SizedBox(height: 16),
                      if (_stats.isEmpty)
                        const Text(
                          'Salve uma medição para consultar os resultados.',
                        ),
                      ..._stats.map(
                        (s) => _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s['nome']} • sessão ${s['sessao_id']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${s['articulacao']} / ${s['movimento']} • ${s['lado']}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${s['tentativas']} tentativa(s)   |   Média ${s['media']} kgf   |   Pico ${s['pico']} kgf',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
