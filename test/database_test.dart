import 'package:sqflite/sqflite.dart' show Sqflite;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dynavoice/data/database.dart';
import 'package:dynavoice/parser_service.dart';
import 'package:dynavoice/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late DynaDatabase store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dynavoice_test_');
    store = await DynaDatabase.open(databaseFactoryFfi, '${dir.path}/test.db');
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test(
    'Seed cria 3 pacientes, 4 sessões, 6 avaliações e 12 medições',
    () async {
      await store.seedDemo();
      for (final entry in {
        'paciente': 3,
        'sessao': 4,
        'avaliacao': 6,
        'medicao': 12,
      }.entries) {
        expect(
          Sqflite.firstIntValue(
            await store.db.rawQuery('SELECT COUNT(*) FROM ${entry.key}'),
          ),
          entry.value,
        );
      }
      expect(await store.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await store.db.rawQuery(
          'PRAGMA integrity_check',
        )).single.values.single,
        'ok',
      );
      await expectLater(store.seedDemo(), throwsStateError);
    },
  );
  test('PK, FK, NOT NULL, CHECK e UNIQUE rejeitam violações', () async {
    await store.seedDemo();
    for (final sql in [
      "INSERT INTO paciente VALUES(1,'Duplicado','2026-09-25')",
      "INSERT INTO paciente(nome,criado_em) VALUES(NULL,'2026-09-25')",
      "INSERT INTO paciente(nome,criado_em) VALUES('  ','2026-09-25')",
      "INSERT INTO paciente(nome,criado_em) VALUES('Nome','data inválida')",
      "INSERT INTO sessao(paciente_id,iniciada_em) VALUES(999,'2026-09-25')",
      "INSERT INTO avaliacao(sessao_id,articulacao,movimento) VALUES(999,'Joelho','Flexão')",
      "INSERT INTO avaliacao(sessao_id,articulacao,movimento) VALUES(1,'Joelho','Flexão')",
      "INSERT INTO medicao(avaliacao_id,lado,forca_kgf,registrada_em,origem) VALUES(999,'Direito',30,'2026-09-25','manual')",
      "UPDATE medicao SET forca_kgf=-1 WHERE id=1",
      "UPDATE medicao SET forca_kgf='abc' WHERE id=1",
      "UPDATE medicao SET lado='Inválido' WHERE id=1",
      "UPDATE medicao SET origem='voz' WHERE id=1",
      "UPDATE sessao SET encerrada_em='2026-01-01' WHERE id=1",
    ]) {
      await expectLater(
        store.db.execute(sql),
        throwsA(isA<DatabaseException>()),
        reason: sql,
      );
    }
    expect((await store.history()).length, 12);
  });
  test(
    'Persistência após fechar/reabrir e separação de pacientes homônimos',
    () async {
      final a = await store.addPatient('Nome Igual');
      final b = await store.addPatient('Nome Igual');
      final session = await store.startSession(a);
      final d = ParserService.processarTextoTranscrito(
        'joelho direito flexão 32,4',
      );
      await store.saveMeasurement(session, d);
      await store.close();
      store = await DynaDatabase.open(
        databaseFactoryFfi,
        '${dir.path}/test.db',
      );
      expect((await store.history(patientId: a)).single['forca_kgf'], 32.4);
      expect(await store.history(patientId: b), isEmpty);
      expect((await store.openSessions()).single['id'], session);
      expect(
        (await store.history()).single['registrada_em'],
        d.registradaEm.toUtc().toIso8601String(),
      );
    },
  );
  test(
    'Agrupa avaliações e transação desfaz criação em caso de falha',
    () async {
      final patient = await store.addPatient('Paciente Teste');
      final session = await store.startSession(patient);
      final d = ParserService.processarTextoTranscrito(
        'joelho direito flexão 32',
      );
      await expectLater(
        store.saveMeasurement(session, d, origin: 'invalida'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await store.db.query('avaliacao'), isEmpty);
      await store.saveMeasurement(session, d);
      await store.saveMeasurement(session, d);
      expect(await store.db.query('avaliacao'), hasLength(1));
      expect(await store.history(), hasLength(2));
      await store.endSession(session);
      await expectLater(store.saveMeasurement(session, d), throwsStateError);
    },
  );
  test(
    'JSON filtrado é arquivo legível com IDs, horário original e zero registros de outro paciente',
    () async {
      await store.seedDemo();
      final file = await ExportService.save(store, dir, patientId: 1);
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(data['pacientes'], hasLength(1));
      expect(data['sessoes'], hasLength(2));
      expect(data['medicoes'], hasLength(8));
      expect(
        (data['medicoes'] as List).firstWhere(
          (m) => m['id'] == 1,
        )['registrada_em'],
        '2026-09-10T09:05:00Z',
      );
      expect(
        await store.exportData(patientId: 1),
        await store.exportData(patientId: 1),
      );
    },
  );
  test('Consultas retornam média, pico e evolução esperados', () async {
    await store.seedDemo();
    final stats = await store.stats(patientId: 1);
    final first = stats.firstWhere(
      (s) =>
          s['sessao_id'] == 1 &&
          s['movimento'] == 'Flexão' &&
          s['lado'] == 'Direito',
    );
    expect(first['media'], 33.2);
    expect(first['pico'], 34.0);
    expect(first['tentativas'], 2);
    final second = stats.firstWhere(
      (s) =>
          s['sessao_id'] == 2 &&
          s['movimento'] == 'Flexão' &&
          s['lado'] == 'Direito',
    );
    expect(second['pico'], 38.0);
  });
  test('Exclusão em cascata preserva dados de outros pacientes', () async {
    await store.seedDemo();
    await store.deletePatient(1);
    expect(await store.patients(), hasLength(2));
    expect(await store.history(), hasLength(4));
    expect(await store.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
