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

  group('Vocabulário e unidades do reconhecimento pt-BR', () {
    for (final example in <(String, double)>[
      (
        'Flexão do joelho direito, trinta e dois vírgula quatro quilos-força.',
        32.4,
      ),
      ('32.4 kgf extensão do ombro esquerdo', 32.4),
      ('ombro esquerdo extensão 18,05 kg', 18.05),
      ('quarenta ponto cinco quilo, abdução do quadril direito', 40.5),
      ('punho direito, vinte e uma quilos, flexão', 21),
      ('quilos-força trinta e dois, tornozelo esquerdo extensão', 32),
    ]) {
      test('interpreta "${example.$1}"', () {
        final data = ParserService.processarTextoTranscrito(example.$1);
        expect(data.forca, example.$2);
        expect(data.validar(), isEmpty);
      });
    }
  });

  test('Reconhece todas as articulações, movimentos e lados previstos', () {
    for (final articulation in ParserService.articulacoes) {
      final data = ParserService.processarTextoTranscrito(
        '$articulation direito flexão 10 kgf',
      );
      expect(data.articulacao, articulation);
    }
    for (final movement in ParserService.movimentos) {
      final data = ParserService.processarTextoTranscrito(
        'joelho esquerdo $movement 10 kgf',
      );
      expect(data.movimento, movement);
      expect(data.lado, 'Esquerdo');
    }
  });

  test('Não adivinha campos ausentes ou entidades ambíguas', () {
    final partial = ParserService.processarTextoTranscrito(
      'flexão direito trinta quilos-força',
    );
    expect(partial.articulacao, isEmpty);
    expect(partial.validar(), contains('Selecione a articulação.'));

    final ambiguous = ParserService.processarTextoTranscrito(
      'joelho e ombro, flexão e extensão, direito e esquerdo, 20 kgf',
    );
    expect(ambiguous.articulacao, isEmpty);
    expect(ambiguous.movimento, isEmpty);
    expect(ambiguous.lado, isEmpty);
    expect(ambiguous.alertas, hasLength(3));
  });

  test('Usa o número junto da unidade e sinaliza números sem referência', () {
    expect(
      ParserService.processarTextoTranscrito(
        'paciente 2, joelho direito flexão 30 kgf',
      ).forca,
      30,
    );
    final ambiguous = ParserService.processarTextoTranscrito(
      'joelho direito flexão, tentativa 2, valor 30',
    );
    expect(ambiguous.forca, isNull);
    expect(ambiguous.alertas, isNotEmpty);
  });

  test('Transcrição parcialmente incorreta permanece para revisão', () {
    const original = 'flexão do joelho direto trinta e dois quilos';
    final data = ParserService.processarTextoTranscrito(original);
    expect(data.textoOriginal, original);
    expect(data.lado, isEmpty);
    expect(data.forca, 32);
    expect(data.validar(), contains('Selecione o lado.'));
  });
}
