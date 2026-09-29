import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../parser_service.dart';

class DynaDatabase {
  final Database db;
  DynaDatabase(this.db);
  static Future<DynaDatabase> open(DatabaseFactory factory, String path) async {
    final schema = await rootBundle.loadString('sql/01_schema.sql');
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await executeScript(db, schema);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE medicao RENAME TO medicao_v1');
            await db.execute('''
              CREATE TABLE medicao (
                id INTEGER PRIMARY KEY,
                avaliacao_id INTEGER NOT NULL REFERENCES avaliacao(id) ON DELETE CASCADE,
                lado TEXT NOT NULL CHECK(lado IN ('Direito','Esquerdo')),
                forca_kgf REAL NOT NULL CHECK(typeof(forca_kgf) IN ('integer','real') AND forca_kgf >= 0 AND forca_kgf <= 1000),
                registrada_em TEXT NOT NULL CHECK(julianday(registrada_em) IS NOT NULL),
                texto_original TEXT NOT NULL DEFAULT '',
                origem TEXT NOT NULL CHECK(origem IN ('manual','voz','simulacao'))
              )
            ''');
            await db.execute('''
              INSERT INTO medicao(id,avaliacao_id,lado,forca_kgf,registrada_em,texto_original,origem)
              SELECT id,avaliacao_id,lado,forca_kgf,registrada_em,texto_original,origem FROM medicao_v1
            ''');
            await db.execute('DROP TABLE medicao_v1');
            await db.execute(
              'CREATE INDEX idx_medicao_avaliacao ON medicao(avaliacao_id)',
            );
          }
        },
      ),
    );
    return DynaDatabase(db);
  }

  static Future<void> executeScript(DatabaseExecutor db, String source) async {
    final cleaned = source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n');
    for (final statement in cleaned.split(';')) {
      if (statement.trim().isNotEmpty) await db.execute(statement.trim());
    }
  }

  Future<List<Map<String, Object?>>> patients() => db.rawQuery(
    'SELECT p.*,COUNT(s.id) AS sessoes FROM paciente p LEFT JOIN sessao s ON s.paciente_id=p.id GROUP BY p.id ORDER BY p.nome',
  );
  Future<int> addPatient(String name) => db.insert('paciente', {
    'nome': name.trim().replaceAll(RegExp(r'\s+'), ' '),
    'criado_em': DateTime.now().toUtc().toIso8601String(),
  });
  Future<int> startSession(int patientId) => db.insert('sessao', {
    'paciente_id': patientId,
    'iniciada_em': DateTime.now().toUtc().toIso8601String(),
  });
  Future<void> endSession(int id) async {
    await db.update(
      'sessao',
      {'encerrada_em': DateTime.now().toUtc().toIso8601String()},
      where: 'id=? AND encerrada_em IS NULL',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> openSessions() => db.rawQuery(
    'SELECT s.*,p.nome FROM sessao s JOIN paciente p ON p.id=s.paciente_id WHERE encerrada_em IS NULL ORDER BY s.id DESC',
  );
  Future<int> saveMeasurement(
    int sessionId,
    DadosAfericao data, {
    String origin = 'manual',
  }) async {
    if (!const {'manual', 'voz', 'simulacao'}.contains(origin)) {
      throw ArgumentError.value(origin, 'origin', 'Origem inválida.');
    }
    final errors = data.validar();
    if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
    return db.transaction((txn) async {
      final sessions = await txn.query(
        'sessao',
        where: 'id=? AND encerrada_em IS NULL',
        whereArgs: [sessionId],
      );
      if (sessions.isEmpty) {
        throw StateError('Sessão inexistente ou encerrada.');
      }
      await txn.rawInsert(
        'INSERT OR IGNORE INTO avaliacao(sessao_id,articulacao,movimento) VALUES(?,?,?)',
        [sessionId, data.articulacao, data.movimento],
      );
      final evaluations = await txn.query(
        'avaliacao',
        where: 'sessao_id=? AND articulacao=? AND movimento=?',
        whereArgs: [sessionId, data.articulacao, data.movimento],
      );
      return txn.insert('medicao', {
        'avaliacao_id': evaluations.single['id'],
        'lado': data.lado,
        'forca_kgf': data.forca,
        'registrada_em': data.registradaEm.toUtc().toIso8601String(),
        'texto_original': data.textoOriginal,
        'origem': origin,
      });
    });
  }

  Future<List<Map<String, Object?>>> history({int? patientId}) => db.rawQuery(
    'SELECT m.*,p.id AS paciente_id,p.nome AS paciente,s.id AS sessao_id,a.articulacao,a.movimento '
    'FROM medicao m JOIN avaliacao a ON a.id=m.avaliacao_id JOIN sessao s ON s.id=a.sessao_id '
    'JOIN paciente p ON p.id=s.paciente_id '
    '${patientId == null ? "" : "WHERE p.id=? "}ORDER BY m.registrada_em DESC,m.id DESC',
    patientId == null ? [] : [patientId],
  );
  Future<List<Map<String, Object?>>> stats({int? patientId}) => db.rawQuery(
    'SELECT p.nome,s.id AS sessao_id,a.articulacao,a.movimento,m.lado,COUNT(*) AS tentativas,'
    'ROUND(AVG(m.forca_kgf),2) AS media,MAX(m.forca_kgf) AS pico FROM medicao m '
    'JOIN avaliacao a ON a.id=m.avaliacao_id JOIN sessao s ON s.id=a.sessao_id '
    'JOIN paciente p ON p.id=s.paciente_id ${patientId == null ? "" : "WHERE p.id=? "}'
    'GROUP BY a.id,m.lado ORDER BY s.iniciada_em DESC,a.id,m.lado',
    patientId == null ? [] : [patientId],
  );
  Future<void> seedDemo() async {
    final sql = await rootBundle.loadString('sql/02_dados_teste.sql');
    await db.transaction((txn) async {
      if (Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM paciente'),
          ) !=
          0) {
        throw StateError(
          'A demonstração só pode ser carregada em banco vazio.',
        );
      }
      await executeScript(txn, sql);
    });
  }

  Future<void> deletePatient(int id) async {
    await db.delete('paciente', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, Object?>> exportData({int? patientId}) => db.transaction((
    txn,
  ) async {
    final patients = await txn.query(
      'paciente',
      where: patientId == null ? null : 'id=?',
      whereArgs: patientId == null ? null : [patientId],
    );
    final sessions = await txn.query(
      'sessao',
      where: patientId == null ? null : 'paciente_id=?',
      whereArgs: patientId == null ? null : [patientId],
    );
    final evaluations = await txn.rawQuery(
      'SELECT a.* FROM avaliacao a JOIN sessao s ON s.id=a.sessao_id ${patientId == null ? "" : "WHERE s.paciente_id=?"}',
      patientId == null ? [] : [patientId],
    );
    final measurements = await txn.rawQuery(
      'SELECT m.* FROM medicao m JOIN avaliacao a ON a.id=m.avaliacao_id JOIN sessao s ON s.id=a.sessao_id ${patientId == null ? "" : "WHERE s.paciente_id=?"}',
      patientId == null ? [] : [patientId],
    );
    return {
      'schema_version': 2,
      'unidade_forca': 'kgf',
      'pacientes': patients,
      'sessoes': sessions,
      'avaliacoes': evaluations,
      'medicoes': measurements,
    };
  });
  Future<void> close() => db.close();
}
