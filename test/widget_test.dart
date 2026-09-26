import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dynavoice/main.dart';
import 'package:dynavoice/data/database.dart';

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
      await tester.tap(find.text('Simular exemplo'));
      await settle(tester);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
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
