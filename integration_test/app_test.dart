import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dynavoice/main.dart';
import 'package:dynavoice/data/database.dart';
import 'package:dynavoice/services/export_service.dart';
import '../test/fakes/fake_speech_recognition_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: SQLite, revisão, histórico, exportação e reabertura', (
    tester,
  ) async {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/integration_test.db';
    await deleteDatabase(path);
    var db = await DynaDatabase.open(databaseFactory, path);
    await db.seedDemo();
    final speech = FakeSpeechRecognitionService();
    await tester.pumpWidget(DynaVoiceApp(database: db, speechService: speech));
    await settle(tester);
    await binding.convertFlutterSurfaceToImage();
    await settle(tester);
    debugPrint('CAPTURANDO TELA');
    await binding.takeScreenshot('01_atendimento');
    await tester.tap(find.text('Carlos Mendes').last);
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('iniciar_sessao')));
    await tester.tap(find.byKey(const Key('iniciar_sessao')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('iniciar_voz')));
    await tester.tap(find.byKey(const Key('iniciar_voz')));
    await settle(tester);
    speech.complete(
      'Flexão do joelho direito, trinta e dois vírgula quatro quilos-força.',
    );
    await settle(tester);
    expect(await db.history(), hasLength(12));
    debugPrint('CAPTURANDO TELA');
    await binding.takeScreenshot('02_revisao');
    await tester.enterText(find.byKey(const Key('forca')), '33,5');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmar_medicao')));
    await settle(tester);
    expect(await db.history(), hasLength(13));
    expect((await db.history()).first['origem'], 'voz');
    ScaffoldMessenger.of(
      tester.element(find.byType(TelaPrincipal)),
    ).clearSnackBars();
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('encerrar_sessao')));
    await tester.tap(find.byKey(const Key('encerrar_sessao')));
    await settle(tester);
    await tester.tap(find.text('Histórico'));
    await settle(tester);
    expect(find.textContaining('33.5 kgf'), findsOneWidget);
    debugPrint('CAPTURANDO TELA');
    await binding.takeScreenshot('03_historico');
    await tester.tap(find.text('Resultados'));
    await settle(tester);
    debugPrint('CAPTURANDO TELA');
    await binding.takeScreenshot('04_resultados');
    final file = await ExportService.save(
      db,
      Directory('${dir.path}/exports'),
      patientId: 1,
    );
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['medicoes'], hasLength(9));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await db.close();
    db = await DynaDatabase.open(databaseFactory, path);
    expect(await db.history(), hasLength(13));
    expect(await db.openSessions(), isEmpty);
    await db.close();
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
