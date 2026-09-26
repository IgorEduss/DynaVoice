# DynaVoice - MVP UEMA / Nota 2

Aplicativo Flutter reconstruído a partir de `DynaVoice-MVP.zip`. Mantém a proposta de registro de aferições e o parser do protótipo, com persistência SQLite, revisão antes da gravação e exportação JSON.

## Abrir e executar

```powershell
git clone https://github.com/IgorEduss/DynaVoice.git
cd DynaVoice
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo-android>
```

Ambiente validado: Flutter 3.44.8, Dart 3.12.2, Android SDK e emulador Pixel 8 / Android 14. A primeira compilação baixa dependências Gradle. `android/local.properties` é gerado pelo Flutter e depende da instalação local. Use `pubspec.lock` para reproduzir as versões. O compartilhamento usa share_plus 10.1.4, compatível com a configuração Android preservada do ZIP. O SDK emite avisos de futura descontinuação dessas versões Gradle/AGP/Kotlin; a atualização conjunta é trabalho futuro.

Windows tem inicialização SQLite via FFI; a compilação desktop exige Visual Studio com ferramentas C++. Não houve validação do aplicativo completo no Windows, iOS ou web. A sobreposição é exclusiva do Android. A versão atual usa `dart:io` e não oferece suporte web.

## Fluxo de demonstração

1. No primeiro uso, toque em **Carregar dados fictícios** (somente banco vazio) ou **Novo paciente**.
2. Selecione um paciente e toque em **Iniciar sessão**.
3. Digite `Flexão de joelho direito 32,4`, toque em **Revisar medição**, confira/corrija e confirme.
4. **Simular exemplo** demonstra o parser sem capturar áudio. A sobreposição também é demonstrativa: envie o exemplo e retorne ao aplicativo para revisar.
5. Encerre a sessão e consulte **Histórico** e **Resultados**. O filtro de paciente também se aplica à exportação.
6. O botão de download salva um JSON na pasta de documentos do aplicativo. No Android, **Compartilhar** abre o seletor do sistema; a escolha do destino cabe ao usuário.
7. Sessões abertas podem ser retomadas após fechar e abrir o aplicativo.

O app começa vazio; nenhum dado fictício é inserido automaticamente em banco com pacientes. Pacientes são identificados por ID, permitindo nomes iguais sem misturar registros. A exclusão exige confirmação e remove o paciente e seus registros dependentes. Zero kgf é permitido; força ausente ou negativa é inválida. A faixa máxima de 1000 kgf é somente uma regra técnica do MVP.

## Arquivos principais

- `lib/main.dart`: interface, revisão e ciclo de atendimento.
- `lib/parser_service.dart`: extração de entidades e força; horário estável.
- `lib/data/database.dart`: repositório SQLite e transações.
- `lib/services/export_service.dart`: exportação para arquivo JSON.
- `lib/overlay.dart`: sobreposição de demonstração.
- `sql/01_schema.sql`: esquema compartilhado pelo app e verificação independente.
- `sql/02_dados_teste.sql`: 3 pacientes, 4 sessões, 6 avaliações e 12 medições fictícias.
- `sql/03_consultas.sql`: 5 consultas com histórico, estatísticas e evolução.
- `docs/`: relatório editável e código original preservado para comparação.
- `output/pdf/`: relatório em PDF.
- `evidencias/`: logs, banco demonstrativo, resultados e capturas.

## Reproduzir verificações

```powershell
flutter analyze
flutter test --reporter expanded
python scripts/verificar_sql.py
flutter drive -d <id-do-emulador> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
flutter build apk --debug
```

`verificar_sql.py` usa apenas a biblioteca padrão do Python e recria **somente** `evidencias/dynavoice_demonstracao.db`. Não aponta para o banco do aplicativo. O teste Android recria apenas `integration_test.db`, separado de `dynavoice.db`.

Para reconstruir o relatório: instale `reportlab` e execute `python scripts/gerar_relatorio.py` após os testes e capturas. O gerador usa Times New Roman do Windows, exige logs aprovados e produz o PDF e o Markdown. O relatório tem seis páginas, incluindo referências, sem capa avulsa. Os autores foram mantidos conforme a Nota 1.

## Limites da versão

A entrada é manual ou simulada; não há captura/transcrição real de voz. Não há autenticação, criptografia, backup, sincronização ou validação clínica. Use apenas dados fictícios nesta etapa. O parser tem vocabulário restrito e não resolve toda ambiguidade: a revisão humana é obrigatória. O teste de integração não valida sobreposição entre aplicativos nem envio por aplicativos de terceiros. Os testes de reabertura verificam a persistência SQLite; não simulam queda de energia.

O relatório e as evidências descrevem somente cenários executados. A publicação neste repositório não substitui a entrega acadêmica no AVA.

