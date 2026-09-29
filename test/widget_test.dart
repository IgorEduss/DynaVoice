import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dynavoice/main.dart';
import 'package:dynavoice/data/database.dart';
import 'package:dynavoice/services/speech_recognition_service.dart';

import 'fakes/fake_speech_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
    'Cadastro, revisão, correção, gravação, histórico e encerramento',
    (tester) async {
      await tester.runAsync(() async {
        final db = await DynaDatabase.open(
          databaseFactoryFfiNoIsolate,
          inMemoryDatabasePath,
        );
        addTearDown(db.close);
        await tester.pumpWidget(DynaVoiceApp(database: db));
        await settle(tester);
        await tester.tap(find.byKey(const Key('novo_paciente')));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('nome_paciente')),
          'Paciente Fictício',
        );
        await tester.tap(find.text('Cadastrar'));
        await settle(tester);
        await tester.tap(find.byKey(const Key('iniciar_sessao')));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('comando')),
          'Flexão de joelho direito 32,4',
        );
        await tester.ensureVisible(find.byKey(const Key('revisar')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('revisar')));
        await settle(tester);
        expect(await db.history(), isEmpty);
        await tester.enterText(find.byKey(const Key('forca')), '-2');
        await tester.tap(find.byKey(const Key('confirmar_medicao')));
        await settle(tester);
        expect(find.text('Informe um número de 0 a 1000.'), findsOneWidget);
        expect(await db.history(), isEmpty);
        await tester.enterText(find.byKey(const Key('forca')), '33,5');
        await tester.tap(find.byKey(const Key('confirmar_medicao')));
        await settle(tester);
        expect((await db.history()).single['forca_kgf'], 33.5);
        ScaffoldMessenger.of(
          tester.element(find.byType(TelaPrincipal)),
        ).clearSnackBars();
        await settle(tester);
        await tester.ensureVisible(find.byKey(const Key('encerrar_sessao')));
        await tester.tap(find.byKey(const Key('encerrar_sessao')));
        await settle(tester);
        expect(await db.openSessions(), isEmpty);
        await tester.tap(find.text('Histórico'));
        await settle(tester);
        expect(find.textContaining('33.5 kgf'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );
  testWidgets('Cancelar revisão não grava uma medição', (tester) async {
    await tester.runAsync(() async {
      final db = await DynaDatabase.open(
        databaseFactoryFfiNoIsolate,
        inMemoryDatabasePath,
      );
      addTearDown(db.close);
      await db.addPatient('Teste Cancelamento');
      await db.startSession(1);
      await tester.pumpWidget(DynaVoiceApp(database: db));
      await settle(tester);
      await tester.tap(find.text('Retomar'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('comando')),
        'Flexão de joelho direito 32,4',
      );
      await tester.ensureVisible(find.byKey(const Key('revisar')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('revisar')));
      await settle(tester);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      expect(await db.history(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Frase incompleta exige correção e não é salva silenciosamente', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final db = await DynaDatabase.open(
        databaseFactoryFfiNoIsolate,
        inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final patient = await db.addPatient('Paciente Fictício Incompleto');
      await db.startSession(patient);
      await tester.pumpWidget(DynaVoiceApp(database: db));
      await settle(tester);
      await tester.tap(find.text('Retomar'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('comando')),
        'Flexão direito trinta quilos-força',
      );
      await tester.ensureVisible(find.byKey(const Key('revisar')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('revisar')));
      await settle(tester);
      expect(
        find.textContaining('interpretação está incompleta'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirmar_medicao')));
      await settle(tester);
      expect(find.text('Selecione a articulação.'), findsOneWidget);
      expect(await db.history(), isEmpty);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      expect(await db.history(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'Voz falsa exibe parcial, exige revisão e salva uma única medição de origem voz',
    (tester) async {
      await tester.runAsync(() async {
        final db = await DynaDatabase.open(
          databaseFactoryFfiNoIsolate,
          inMemoryDatabasePath,
        );
        addTearDown(db.close);
        final patient = await db.addPatient('Paciente Fictício Voz');
        await db.startSession(patient);
        final speech = FakeSpeechRecognitionService();

        await tester.pumpWidget(
          DynaVoiceApp(database: db, speechService: speech),
        );
        await settle(tester);
        await tester.tap(find.text('Retomar'));
        await settle(tester);
        await tester.ensureVisible(find.byKey(const Key('iniciar_voz')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('iniciar_voz')));
        await settle(tester);
        expect(find.textContaining('Voz: Ouvindo'), findsOneWidget);

        speech.emit(
          const SpeechCaptureSnapshot(
            SpeechCaptureState.listening,
            transcript: 'Flexão do joelho direito',
            message: 'Ouvindo… resultado parcial.',
          ),
        );
        await settle(tester);
        expect(find.byKey(const Key('transcricao_voz')), findsOneWidget);
        expect(await db.history(), isEmpty);

        const transcript =
            'Flexão do joelho direito, trinta e dois vírgula quatro quilos-força.';
        speech.complete(transcript);
        await settle(tester);
        final originalFinder = find.byKey(const Key('texto_original_revisao'));
        expect(originalFinder, findsOneWidget);
        expect(tester.widget<Text>(originalFinder).data, transcript);
        expect(await db.history(), isEmpty);
        await tester.tap(find.byKey(const Key('confirmar_medicao')));
        await settle(tester);

        final history = await db.history();
        expect(history, hasLength(1));
        expect(history.single['forca_kgf'], 32.4);
        expect(history.single['origem'], 'voz');
        expect(history.single['texto_original'], transcript);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets('Cancelar captura de voz não abre revisão nem grava', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final db = await DynaDatabase.open(
        databaseFactoryFfiNoIsolate,
        inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final patient = await db.addPatient('Paciente Fictício Cancelamento');
      await db.startSession(patient);
      final speech = FakeSpeechRecognitionService();
      await tester.pumpWidget(
        DynaVoiceApp(database: db, speechService: speech),
      );
      await settle(tester);
      await tester.tap(find.text('Retomar'));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('iniciar_voz')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('iniciar_voz')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('cancelar_voz')));
      await settle(tester);
      expect(find.textContaining('Voz: Cancelado'), findsOneWidget);
      expect(find.byKey(const Key('texto_original_revisao')), findsNothing);
      expect(await db.history(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
