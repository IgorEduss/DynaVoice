import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await Directory('evidencias/telas').create(recursive: true);
      await File('evidencias/telas/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
