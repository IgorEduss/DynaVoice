import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dynavoice/data/database.dart';
import 'package:dynavoice/main.dart';
import 'package:dynavoice/services/speech_recognition_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android: entrada manual com revisão e persistência', (
    tester,
  ) async {
    final directory = await getApplicationSupportDirectory();
    final path = '${directory.path}/integracao_manual.db';
    await deleteDatabase(path);
    final db = await DynaDatabase.open(databaseFactory, path);
    await db.seedDemo();
    final speech = DeviceSpeechRecognitionService();
    await tester.pumpWidget(DynaVoiceApp(database: db, speechService: speech));
    await settle(tester);
    await binding.convertFlutterSurfaceToImage();
    await settle(tester);
    await tester.tap(find.text('Carlos Mendes').last);
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('iniciar_sessao')));
    await tester.tap(find.byKey(const Key('iniciar_sessao')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('comando')));
    await tester.enterText(
      find.byKey(const Key('comando')),
      'Flexão do joelho direito, trinta e dois vírgula quatro.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await binding.takeScreenshot('05_entrada_manual');
    await tester.ensureVisible(find.byKey(const Key('revisar')));
    await tester.tap(find.byKey(const Key('revisar')));
    await settle(tester);
    await binding.takeScreenshot('06_revisao_manual');
    expect(await db.history(), hasLength(12));
    await tester.tap(find.byKey(const Key('confirmar_medicao')));
    await settle(tester);
    final history = await db.history();
    expect(history, hasLength(13));
    expect(history.first['origem'], 'manual');
    expect(history.first['forca_kgf'], 32.4);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await db.close();
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
