# DynaVoice — MVP acadêmico funcional

Aplicativo Android em Flutter para registrar aferições fictícias de força por voz ou digitação. A versão atual substitui a simulação interna por reconhecimento de fala do Android em português brasileiro, interpreta a transcrição, exige revisão editável e somente então grava no SQLite.

O DynaVoice é um protótipo acadêmico. Não demonstra eficácia clínica, conformidade regulatória, proteção suficiente para dados reais nem reconhecimento perfeito. Use apenas dados fictícios.

## Fluxo implementado

1. Crie ou carregue pacientes fictícios, selecione um paciente e inicie uma sessão.
2. Toque em **Ditar em pt-BR**. No primeiro uso, o Android solicita acesso ao microfone.
3. Fale, por exemplo: **“Flexão do joelho direito, trinta e dois vírgula quatro quilos-força.”**
4. A tela mostra os estados do reconhecedor e a transcrição parcial/definitiva.
5. O parser apresenta articulação, movimento, lado e força em uma revisão editável.
6. Corrija o que for necessário. Campos ausentes ou ambíguos não são inventados e impedem a confirmação.
7. **Cancelar** não cria medição. **Confirmar e salvar** cria uma única medição.
8. Histórico, resultados e exportação JSON passam a refletir o registro confirmado.

A entrada manual continua disponível pelo botão **Digitar medição**. A transcrição original e a origem (`voz` ou `manual`) são preservadas no banco.

## Reconhecimento de voz

O contrato `SpeechRecognitionService` separa a interface do mecanismo de reconhecimento. O aplicativo Android usa `DeviceSpeechRecognitionService`, baseado no reconhecedor disponível no sistema, com localidade `pt_BR`, resultados parciais e definitivos. Os testes usam `FakeSpeechRecognitionService`, sem depender de microfone, rede ou serviço instalado.

Estados apresentados: permissão necessária, pronto, ouvindo, processando, resultado, cancelado, indisponível e erro. Se o serviço não estiver disponível, o aplicativo informa a condição e mantém a entrada manual.

O reconhecimento depende do aparelho e do serviço de fala instalado. Alguns dispositivos usam rede. A qualidade da transcrição varia com ruído, pronúncia e vocabulário.

## Sobreposição Android

Depois de autorizar o microfone no aplicativo principal, use **Abrir sobreposição** e conceda a permissão de exibição sobre outros aplicativos. O overlay usa o mesmo serviço real, permite ditar, concluir ou cancelar e devolve somente a transcrição ao DynaVoice. A revisão no aplicativo principal continua obrigatória antes de salvar.

Nesta execução, o envio e o cancelamento do overlay foram cobertos por testes automatizados. A validação manual entre aplicativos e versões do Android continua pendente em aparelho físico.

## Executar

Pré-requisitos: Flutter 3.44.8 ou compatível, Android SDK, um aparelho/emulador Android e um serviço de reconhecimento de fala com português do Brasil.

```powershell
git clone https://github.com/IgorEduss/DynaVoice.git
cd DynaVoice
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo-android>
```

Para validar o reconhecimento real, conecte um aparelho Android com depuração USB, confirme que ele aparece em `flutter devices`, execute o aplicativo e faça o roteiro descrito em `evidencias/VERIFICACAO_FINAL.md`.

## Verificações reproduzíveis

```powershell
flutter analyze
flutter test --reporter expanded
python scripts/verificar_sql.py
flutter drive -d <id-do-emulador> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
flutter build apk --debug
```

Resultados desta revisão:

- análise estática sem apontamentos;
- 35 testes Dart/Flutter aprovados;
- 24 verificações SQLite/Python aprovadas e cinco consultas exportadas;
- um cenário Android de integração aprovado no Pixel 8 / Android 14, usando serviço de voz falso;
- APK de depuração gerado;
- relatório PDF de seis páginas e apresentação de 12 slides renderizados e inspecionados;
- quatro capturas e vídeo de 41 segundos do fluxo automatizado no emulador.

O cenário de integração cobre transcrição parcial/definitiva falsa, revisão, correção, cancelamento, confirmação única, persistência após reabrir, histórico, estatísticas e exportação. Ele prova o fluxo do aplicativo, não a captura física do microfone.

## Arquivos principais

- `lib/main.dart`: atendimento, estados de voz e revisão obrigatória.
- `lib/services/speech_recognition_service.dart`: interface e implementação Android.
- `lib/parser_service.dart`: entidades, números falados, unidades e ambiguidades.
- `lib/data/database.dart`: SQLite, migração para esquema v2 e transações.
- `lib/services/export_service.dart`: exportação JSON.
- `lib/overlay.dart`: sobreposição com ditado real e retorno para revisão.
- `test/`: parser, persistência, serviço falso, widgets e overlay.
- `integration_test/app_test.dart`: fluxo completo reproduzível no Android.
- `sql/`: esquema, dados fictícios e consultas independentes.
- `evidencias/`: logs, banco demonstrativo, CSVs, capturas e vídeo.
- `docs/Relatorio_Nota2_DynaVoice.md`: relatório editável.
- `output/pdf/Relatorio_Nota2_DynaVoice.pdf`: relatório final.
- `output/apresentacao/DynaVoice_Nota3_Atualizada.pptx`: apresentação atualizada.

`scripts/verificar_sql.py` recria somente `evidencias/dynavoice_demonstracao.db`. O teste Android usa `integration_test.db`, separado do banco normal do aplicativo.

## Limitações restantes

- Não havia aparelho Android físico conectado nesta execução; portanto, não há evidência atual de microfone real em hardware.
- O overlay real entre aplicativos ainda precisa de validação manual em aparelho físico.
- O reconhecedor do Android pode estar indisponível e sua precisão não é garantida.
- O parser usa vocabulário controlado; campos ausentes ou ambíguos exigem correção humana.
- Não há autenticação, criptografia, backup ou sincronização.
- Não houve validação clínica, regulatória, de acessibilidade, desempenho ou uso com dados reais.
- O SDK emite avisos de futura atualização conjunta de Gradle, AGP e Kotlin; o build atual termina com sucesso.

As evidências registram somente os cenários realmente executados. A publicação no GitHub não substitui a entrega acadêmica no AVA.
