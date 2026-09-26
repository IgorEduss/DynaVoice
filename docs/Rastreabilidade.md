# Rastreabilidade da Nota 2

| Critério | Implementação | Evidência |
|---|---|---|
| Estrutura SQL (2,5) | sql/01_schema.sql; lib/data/database.dart | banco demonstrativo e testes SQLite |
| PK, FK e integridade (2,0) | PK/FK, CHECK, NOT NULL, UNIQUE, transações, PRAGMA por conexão | testes negativos e foreign_key_check |
| Dados coerentes (1,5) | sql/02_dados_teste.sql | 3 pacientes, 4 sessões, 6 avaliações, 12 medições |
| Consultas úteis (2,5) | sql/03_consultas.sql; histórico/resultados no app | 5 CSVs, média 33,2 kgf e picos 34/38 kgf |
| Relatório, scripts e resultados (1,5) | docs/Relatorio_Nota2_DynaVoice.md; output/pdf | relatório técnico, logs e capturas |

## Relação com os requisitos da Nota 1

- RF01/RF02: captura e transcrição local pendentes; simulação explicitamente identificada.
- RF03/RF04: extração textual de articulação, movimento, lado e força; paciente selecionado na interface, não inferido da fala.
- RF05: código de sobreposição demonstrativa mantido; validação entre aplicativos e aparelhos físicos pendente.
- RF06: revisão e edição antes da gravação; cancelar não cria registro.
- RF07: pacientes, sessões, avaliações e medições persistidos no SQLite.
- RF08: arquivo JSON com IDs, vínculos e horários originais; filtro por paciente.

Não há alegação de conformidade LGPD, precisão clínica, reconhecimento de voz ou cobertura total de testes.
