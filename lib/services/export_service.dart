import 'dart:convert';
import 'dart:io';
import '../data/database.dart';

class ExportService {
  static Future<File> save(
    DynaDatabase database,
    Directory directory, {
    int? patientId,
  }) async {
    final data = await database.exportData(patientId: patientId);
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}dynavoice_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return file;
  }
}
