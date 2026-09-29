class DadosAfericao {
  String paciente;
  String articulacao;
  String movimento;
  String lado;
  double? forca;
  final DateTime registradaEm;
  String textoOriginal;
  final List<String> alertas;

  DadosAfericao({
    this.paciente = 'Geral',
    this.articulacao = '',
    this.movimento = '',
    this.lado = '',
    this.forca,
    this.textoOriginal = '',
    List<String>? alertas,
    DateTime? registradaEm,
  }) : alertas = alertas ?? <String>[],
       registradaEm = registradaEm ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
    'paciente': paciente,
    'articulação': articulacao,
    'movimento': movimento,
    'lado': lado,
    'força_kgf': forca,
    'texto_original': textoOriginal,
    'timestamp': registradaEm.toUtc().toIso8601String(),
  };

  List<String> validar() {
    final errors = <String>[];
    if (!ParserService.articulacoes.contains(articulacao)) {
      errors.add('Selecione a articulação.');
    }
    if (!ParserService.movimentos.contains(movimento)) {
      errors.add('Selecione o movimento.');
    }
    if (!ParserService.lados.contains(lado)) {
      errors.add('Selecione o lado.');
    }
    if (forca == null || !forca!.isFinite || forca! < 0 || forca! > 1000) {
      errors.add('Informe força válida entre 0 e 1000 kgf.');
    }
    return errors;
  }

  @override
  String toString() =>
      'DadosAfericao(articulação: $articulacao, movimento: $movimento, lado: $lado, força: $forca kgf)';
}

/// Parser determinístico para a linguagem restrita do MVP acadêmico.
///
/// Ele extrai somente valores explicitamente presentes. Mais de uma opção para
/// o mesmo campo é tratada como ambiguidade e deixada em branco para revisão.
class ParserService {
  static const articulacoes = [
    'Joelho',
    'Ombro',
    'Cotovelo',
    'Quadril',
    'Punho',
    'Tornozelo',
  ];
  static const movimentos = [
    'Flexão',
    'Extensão',
    'Abdução',
    'Adução',
    'Rotação Interna',
    'Rotação Externa',
  ];
  static const lados = ['Direito', 'Esquerdo'];

  static const Map<String, List<String>> _articulationTerms = {
    'Joelho': ['joelho'],
    'Ombro': ['ombro'],
    'Cotovelo': ['cotovelo'],
    'Quadril': ['quadril'],
    'Punho': ['punho'],
    'Tornozelo': ['tornozelo'],
  };
  static const Map<String, List<String>> _movementTerms = {
    'Rotação Interna': ['rotacao interna'],
    'Rotação Externa': ['rotacao externa'],
    'Flexão': ['flexao'],
    'Extensão': ['extensao'],
    'Abdução': ['abducao'],
    'Adução': ['aducao'],
  };
  static const Map<String, List<String>> _sideTerms = {
    'Direito': ['direito', 'direita', 'dir'],
    'Esquerdo': ['esquerdo', 'esquerda', 'esq'],
  };

  static const Map<String, int> _numberWords = {
    'zero': 0,
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
    'onze': 11,
    'doze': 12,
    'treze': 13,
    'quatorze': 14,
    'catorze': 14,
    'quinze': 15,
    'dezesseis': 16,
    'dezessete': 17,
    'dezoito': 18,
    'dezenove': 19,
    'vinte': 20,
    'trinta': 30,
    'quarenta': 40,
    'cinquenta': 50,
    'sessenta': 60,
    'setenta': 70,
    'oitenta': 80,
    'noventa': 90,
    'cem': 100,
    'cento': 100,
    'duzentos': 200,
    'duzentas': 200,
    'trezentos': 300,
    'trezentas': 300,
    'quatrocentos': 400,
    'quatrocentas': 400,
    'quinhentos': 500,
    'quinhentas': 500,
    'seiscentos': 600,
    'seiscentas': 600,
    'setecentos': 700,
    'setecentas': 700,
    'oitocentos': 800,
    'oitocentas': 800,
    'novecentos': 900,
    'novecentas': 900,
    'mil': 1000,
  };
  static const _decimalSeparators = {'virgula', 'ponto'};
  static final _unitPattern = RegExp(
    r'\b(?:kgf|kg|quilo|quilos)(?:[\s-]*(?:forca))?\b',
  );

  static DadosAfericao processarTextoTranscrito(String textoBruto) {
    final normalized = _normalize(textoBruto);
    final data = DadosAfericao(textoOriginal: textoBruto);
    data.articulacao = _resolveEntity(
      normalized,
      _articulationTerms,
      'articulação',
      data.alertas,
    );
    data.movimento = _resolveEntity(
      normalized,
      _movementTerms,
      'movimento',
      data.alertas,
    );
    data.lado = _resolveEntity(normalized, _sideTerms, 'lado', data.alertas);
    data.forca = _extractForce(normalized, data.alertas);
    return data;
  }

  static String _resolveEntity(
    String text,
    Map<String, List<String>> terms,
    String label,
    List<String> warnings,
  ) {
    final matches = <String>[];
    for (final entry in terms.entries) {
      if (entry.value.any((term) => _containsTerm(text, term))) {
        matches.add(entry.key);
      }
    }
    if (matches.length == 1) return matches.single;
    if (matches.length > 1) {
      warnings.add(
        'Mais de um $label foi reconhecido (${matches.join(' / ')}). Selecione o correto.',
      );
    }
    return '';
  }

  static bool _containsTerm(String text, String term) => RegExp(
    '(?:^|[^a-z0-9])${RegExp.escape(term)}(?:\$|[^a-z0-9])',
  ).hasMatch(text);

  static double? _extractForce(String text, List<String> warnings) {
    if (RegExp(r'(?:^|\s)(?:menos|-|−)\s*(?:\d|[a-z])').hasMatch(text)) {
      warnings.add('Valor negativo reconhecido; informe uma força válida.');
      return null;
    }
    final candidates = <_NumberCandidate>[];
    for (final match in RegExp(r'\b\d+(?:[.,]\d+)?\b').allMatches(text)) {
      final value = double.tryParse(match.group(0)!.replaceAll(',', '.'));
      if (value != null) {
        candidates.add(_NumberCandidate(value, match.start, match.end));
      }
    }

    final tokens = RegExp(r'[a-z]+').allMatches(text).toList();
    for (var index = 0; index < tokens.length; index++) {
      if (!_numberWords.containsKey(tokens[index].group(0))) continue;
      final sequence = <String>[];
      var endIndex = index;
      var sawSeparator = false;
      for (var cursor = index; cursor < tokens.length; cursor++) {
        final token = tokens[cursor].group(0)!;
        final previousEnd = cursor == index
            ? tokens[cursor].start
            : tokens[cursor - 1].end;
        final between = text.substring(previousEnd, tokens[cursor].start);
        if (cursor > index && between.trim().isNotEmpty) break;
        if (_numberWords.containsKey(token)) {
          sequence.add(token);
        } else if (token == 'e') {
          if (sequence.isEmpty || sequence.last == 'e' || sawSeparator) break;
          sequence.add(token);
        } else if (_decimalSeparators.contains(token) && !sawSeparator) {
          if (sequence.isEmpty || sequence.last == 'e') break;
          sawSeparator = true;
          sequence.add(token);
        } else {
          break;
        }
        endIndex = cursor;
      }
      while (sequence.isNotEmpty && sequence.last == 'e') {
        sequence.removeLast();
        endIndex--;
      }
      final value = _parseWordNumber(sequence);
      if (value != null) {
        candidates.add(
          _NumberCandidate(value, tokens[index].start, tokens[endIndex].end),
        );
        index = endIndex;
      }
    }

    final unique = <_NumberCandidate>[];
    for (final candidate in candidates) {
      if (!unique.any(
        (other) => other.start == candidate.start && other.end == candidate.end,
      )) {
        unique.add(candidate);
      }
    }
    if (unique.isEmpty) return null;
    if (unique.length == 1) return unique.single.value;

    final unitMatches = _unitPattern.allMatches(text).toList();
    final unitBound = unique.where((candidate) {
      return unitMatches.any((unit) {
        final distance = candidate.end <= unit.start
            ? unit.start - candidate.end
            : candidate.start >= unit.end
            ? candidate.start - unit.end
            : 0;
        return distance <= 18;
      });
    }).toList();
    if (unitBound.length == 1) return unitBound.single.value;
    warnings.add(
      'Mais de um número foi reconhecido; informe qual corresponde à força em kgf.',
    );
    return null;
  }

  static double? _parseWordNumber(List<String> sequence) {
    if (sequence.isEmpty) return null;
    final separator = sequence.indexWhere(_decimalSeparators.contains);
    final integerTokens = separator < 0
        ? sequence
        : sequence.sublist(0, separator);
    final decimalTokens = separator < 0
        ? const <String>[]
        : sequence.sublist(separator + 1);
    if (integerTokens.isEmpty || (separator >= 0 && decimalTokens.isEmpty)) {
      return null;
    }
    final integer = _sumNumberWords(integerTokens);
    if (integer == null) return null;
    if (decimalTokens.isEmpty) return integer.toDouble();
    final significant = decimalTokens.where((token) => token != 'e').toList();
    if (significant.every((token) => (_numberWords[token] ?? 10) < 10)) {
      final digits = significant.map((token) => _numberWords[token]).join();
      return double.parse('$integer.$digits');
    }
    final decimal = _sumNumberWords(decimalTokens);
    if (decimal == null) return null;
    return integer + decimal / _pow10(decimal.toString().length);
  }

  static int? _sumNumberWords(List<String> tokens) {
    var total = 0;
    for (final token in tokens) {
      if (token == 'e') continue;
      final value = _numberWords[token];
      if (value == null) return null;
      total += value;
    }
    return total;
  }

  static double _pow10(int exponent) {
    var value = 1.0;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }

  static String _normalize(String source) {
    var value = source.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    replacements.forEach((from, to) => value = value.replaceAll(from, to));
    return value
        .replaceAll(RegExp(r'[^a-z0-9.,\-\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _NumberCandidate {
  final double value;
  final int start;
  final int end;

  const _NumberCandidate(this.value, this.start, this.end);
}
