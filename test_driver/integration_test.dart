import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final configured = Platform.environment['DYNAVOICE_EVIDENCIAS'];
  final destination = configured == null || configured.isEmpty
      ? 'build/evidencias/telas'
      : configured;
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await Directory(destination).create(recursive: true);
      await File('$destination/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
