UNIVERSIDADE ESTADUAL DO MARANHÃO

Curso Superior de Tecnologia em Análise e Desenvolvimento de Sistemas - Gestão da Qualidade e Teste de Software

Anderson Silva da Cunha - Igor Eduardo da Silva Souza

DYNAVOICE: DESENVOLVIMENTO, TESTES E MELHORIA DO MVP

Nota 2 - Axixá - 2026

## 1 INTRODUÇÃO

O DynaVoice é uma proposta de aplicativo móvel destinada a fisioterapeutas para organizar registros de força obtidos por dinamometria. A Nota 1 estabeleceu requisitos de captura de voz, interpretação de comandos, revisão dos dados, persistência e exportação, além da hierarquia Paciente, Sessão, Avaliação e Medição. Esta etapa aperfeiçoou o protótipo Flutter, priorizando o armazenamento relacional e a validação dos registros, em correspondência com os critérios avaliativos da Nota 2.

## 2 DESCRIÇÃO DO PROTÓTIPO/MVP

A versão recebida já continha telas, um analisador textual baseado em expressões regulares e código de sobreposição Android. Entretanto, o histórico permanecia em memória, a entrada de voz era simulada por frases predefinidas e o JSON era apenas exibido. A versão aperfeiçoada cadastra pacientes, inicia e retoma sessões, revisa medições antes da gravação, consulta histórico e estatísticas e salva arquivos JSON.

O reconhecimento de áudio permanece fora do escopo implementado. O aplicativo identifica a entrada manual e a simulação, sem apresentar exemplos predefinidos como fala reconhecida. Os dados empregados na validação são fictícios. Os resultados apresentados neste relatório decorrem da execução dos scripts e testes incluídos no projeto.


<!-- quebra de página -->

## 3 DESENVOLVIMENTO DA SOLUÇÃO

A aplicação foi organizada em interface, parser, repositório SQLite e serviço de exportação. O código original foi preservado em docs/ para comparação. O esquema SQL distribuído com o aplicativo é o mesmo empregado na verificação independente, evitando divergência entre documentação e implementação.

| Entidade | Responsabilidade e integridade |
| --- | --- |
| Paciente | PK id; nome obrigatório com 2 a 120 caracteres; data de criação válida. |
| Sessão | PK id; FK paciente_id; início obrigatório; encerramento não anterior ao início. |
| Avaliação | PK id; FK sessao_id; articulação e movimento controlados; UNIQUE por sessão, articulação e movimento. |
| Medição | PK id; FK avaliacao_id; lado e origem controlados; força numérica; horário original e texto preservados. |

Relacionamentos: Paciente 1:N Sessão; Sessão 1:N Avaliação; Avaliação 1:N Medição. Articulação e movimento ficam na avaliação, evitando sua repetição nas medições. Cada tentativa registra lado e força. A exclusão de um paciente exige confirmação na interface e propaga-se às entidades dependentes por ON DELETE CASCADE.

```sql
PRAGMA foreign_keys = ON;
CREATE TABLE medicao (
 id INTEGER PRIMARY KEY,
 avaliacao_id INTEGER NOT NULL
   REFERENCES avaliacao(id) ON DELETE CASCADE,
 lado TEXT NOT NULL CHECK(lado IN ('Direito','Esquerdo')),
 forca_kgf REAL NOT NULL CHECK(
   typeof(forca_kgf) IN ('integer','real')
   AND forca_kgf >= 0 AND forca_kgf <= 1000),
 ...
);
```

Trecho abreviado; o script completo é sql/01_schema.sql. A faixa de 0 a 1000 kgf é uma regra técnica do MVP, não um limite clínico validado. A gravação da avaliação e da medição ocorre em transação. O repositório rejeita novas medições em sessões encerradas.


<!-- quebra de página -->

## 3.1 DADOS DE TESTE E CONSULTAS SQL

O script sql/02_dados_teste.sql insere 3 pacientes fictícios, 4 sessões, 6 avaliações e 12 medições. Carlos Mendes possui duas sessões comparáveis; Ana Beatriz e Ricardo Ferreira permitem verificar separação por paciente. O carregamento de demonstração na interface só é permitido em banco vazio.

| Consulta | Informação produzida |
| --- | --- |
| Q1 | Histórico com paciente, sessão, articulação, movimento, lado, força, horário e origem. |
| Q2 | Quantidade de tentativas, média e pico por avaliação e lado. |
| Q3 | Evolução do pico de flexão do joelho direito do paciente 1. |
| Q4 | Quantidade de sessões por paciente, incluindo pacientes sem sessão por LEFT JOIN. |
| Q5 | Picos direito e esquerdo por avaliação; ausência de lado resulta em NULL. |

```sql
SELECT s.iniciada_em, MAX(m.forca_kgf) AS pico_kgf
FROM medicao m
JOIN avaliacao a ON a.id=m.avaliacao_id
JOIN sessao s ON s.id=a.sessao_id
WHERE s.paciente_id=1 AND a.articulacao='Joelho'
 AND a.movimento='Flexão' AND m.lado='Direito'
GROUP BY s.id ORDER BY s.iniciada_em;
```

| Resultado verificado | Valor obtido |
| --- | --- |
| Média da flexão direita, primeira sessão | 33,2 kgf (32,4 e 34,0; duas tentativas) |
| Pico em 10/09/2026 | 34,0 kgf |
| Pico em 20/09/2026 | 38,0 kgf |

Fonte: execução de sql/03_consultas.sql sobre o banco fictício. Os resultados completos estão em evidencias/consulta_1.csv a consulta_5.csv. A diferença entre os picos é descritiva e não demonstra evolução clínica real.


<!-- quebra de página -->

## 4 TESTES INICIAIS

A validação combinou 23 verificações independentes em SQLite/Python, 16 testes automatizados Dart/Flutter e um teste de integração Android. O analisador estático terminou sem problemas. O ambiente utilizou Flutter 3.44.8, Dart 3.12.2 e emulador Android Pixel 8. Os registros de execução estão na pasta evidencias/.

| Procedimento / resultado esperado | Resultado obtido |
| --- | --- |
| Criar esquema e inserir o conjunto fictício. | 3 pacientes, 4 sessões, 6 avaliações e 12 medições; integridade do banco: ok. |
| Tentar PK duplicada, FK inexistente, nome nulo/vazio, lado inválido e força negativa/textual. | Operações rejeitadas; conjunto válido preservado. |
| Gravar, fechar e reabrir o banco. | Medições e sessões abertas recuperadas. |
| Forçar falha na inserção após criar a avaliação. | Transação revertida; avaliação parcial não permaneceu. |
| Interpretar 32,4; números por extenso; decimal com zero inicial. | Valores esperados reconhecidos; ausência de força distinguida de zero. |
| Revisar, corrigir a força e confirmar; cancelar outra revisão. | Correção gravada; cancelamento não gerou medição. |
| Exportar JSON do paciente 1. | Arquivo legível com IDs e horários originais; dados de outros pacientes excluídos. |
| Executar fluxo Android e reabrir banco nativo. | 12 registros iniciais; 13 após inclusão; 9 no JSON filtrado; registros recuperados após reabertura. |

Arquivos: flutter_analyze.txt, flutter_test.txt, testes_sql.txt, resultados_sql.json e integracao_android.txt. As contagens correspondem a verificações executadas, não a uma certificação de qualidade ou cobertura integral de caminhos.


<!-- quebra de página -->

## 5 FALHAS, BUGS E MELHORIAS

| Problema identificado | Correção ou tratamento |
| --- | --- |
| Histórico apenas em memória. | SQLite integrado; sessões abertas podem ser retomadas. |
| Timestamp alterado a cada exportação. | Horário capturado na criação do registro e preservado. |
| Ausência de valor interpretada como zero. | Valor ausente é nulo; revisão exige preenchimento válido. |
| Números negativos e pontuação mal interpretados. | Rejeição de negativos/entradas numéricas ambíguas; correção de pontuação e decimais por extenso. |
| Registro sem conferência e JSON apenas em janela. | Confirmação e edição antes da gravação; exportação para arquivo. |

## 6 EVIDÊNCIAS DA ATIVIDADE

Figura 1 - Revisão antes da gravação e histórico persistido no emulador Android. Fonte: capturas obtidas durante o teste de integração, 25 set. 2026.

![Revisão](../evidencias/telas/02_revisao.png)

![Histórico](../evidencias/telas/03_historico.png)

Os scripts SQL, o banco de demonstração, os CSVs e os testes acompanham o projeto. Não foi publicado repositório ou ambiente online nesta etapa.


<!-- quebra de página -->

## 7 LIMITAÇÕES E MELHORIAS PROPOSTAS

A transcrição de áudio não foi integrada. O parser trabalha com vocabulário limitado, não resolve toda ambiguidade de linguagem natural e depende da revisão humana. A sobreposição é demonstrativa; seu comportamento entre aplicativos e versões Android exige validação adicional em aparelho físico. O teste Android cobre o fluxo interno de registros, não a captura de voz ou o compartilhamento por aplicativos externos.

Não foram implementados autenticação, criptografia do banco, backup automático ou sincronização. O armazenamento local, por si só, não comprova conformidade legal nem segurança suficiente para uso clínico. O protótipo deve permanecer em avaliação com dados fictícios. Também não foram realizados ensaios de desempenho, acessibilidade ou validação clínica. A próxima etapa poderá integrar transcrição local e ampliar esses testes, preservando a revisão antes de salvar.

## 8 CONCLUSÃO

O aperfeiçoamento transformou o histórico volátil em persistência relacional organizada, com integridade referencial, transações, consultas úteis e exportação reproduzível. Os testes executados demonstraram o funcionamento dos cenários previstos e orientaram correções no tratamento numérico e no fluxo de gravação. O principal aprendizado foi relacionar requisitos, restrições de dados e evidências de execução, distinguindo funcionalidades implementadas de recursos ainda planejados. Assim, a Nota 2 avança o requisito de persistência da Nota 1 e mantém explícitos os limites do MVP.

## REFERÊNCIAS

CUNHA, Anderson Silva da; SOUZA, Igor Eduardo da Silva. DynaVoice: análise da qualidade da proposta tecnológica para registro de aferições de força por voz. Axixá: UEMA, 2026. Relatório técnico da Nota 1.

SQLITE. Foreign Key Support. Disponível em: https://www.sqlite.org/foreignkeys.html. Acesso em: 25 set. 2026.

TEKARTIK. sqflite: SQLite plugin for Flutter. Disponível em: https://pub.dev/packages/sqflite. Acesso em: 25 set. 2026.

FLUTTER. Integration testing. Disponível em: https://docs.flutter.dev/testing/integration-tests. Acesso em: 25 set. 2026.
