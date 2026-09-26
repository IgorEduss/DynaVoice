import 'package:flutter_test/flutter_test.dart';
import 'package:dynavoice/parser_service.dart';

void main() {
  test('Interpreta número por extenso e entidades', () {
    final d = ParserService.processarTextoTranscrito(
      'Flexão de joelho direito trinta e dois vírgula quatro',
    );
    expect(d.forca, 32.4);
    expect(d.articulacao, 'Joelho');
    expect(d.movimento, 'Flexão');
    expect(d.lado, 'Direito');
    expect(d.validar(), isEmpty);
  });
  test('Preserva decimal com zero inicial', () {
    expect(
      ParserService.processarTextoTranscrito(
        'joelho direito flexão trinta e dois vírgula zero cinco',
      ).forca,
      32.05,
    );
  });
  test('Ignora pontuação periférica nos numerais', () {
    expect(
      ParserService.processarTextoTranscrito(
        'cento e quarenta e cinco, joelho direito, flexão',
      ).forca,
      145,
    );
  });
  test('Distingue valor ausente de zero', () {
    expect(
      ParserService.processarTextoTranscrito('joelho direito flexão').forca,
      isNull,
    );
    expect(
      ParserService.processarTextoTranscrito(
        'joelho direito flexão zero',
      ).forca,
      0,
    );
  });
  test('Rejeita sinais negativos, números ambíguos e campos ausentes', () {
    for (final text in [
      'joelho direito flexão -10',
      'joelho direito flexão menos dez',
      'paciente 2 joelho direito flexão 30',
    ]) {
      expect(ParserService.processarTextoTranscrito(text).forca, isNull);
    }
    expect(
      ParserService.processarTextoTranscrito('32').validar(),
      hasLength(3),
    );
  });
  test('Aceita vírgula decimal e impede força fora da faixa', () {
    expect(
      ParserService.processarTextoTranscrito(
        'joelho direito flexão 18,18',
      ).forca,
      18.18,
    );
    expect(
      ParserService.processarTextoTranscrito(
        'joelho direito flexão 1001',
      ).validar(),
      isNotEmpty,
    );
  });
  test('Timestamp pertence à medição e não muda ao serializar', () {
    final d = DadosAfericao(registradaEm: DateTime.utc(2026, 9, 25, 10));
    expect(d.toJson()['timestamp'], '2026-09-25T10:00:00.000Z');
    expect(d.toJson(), d.toJson());
  });
}
