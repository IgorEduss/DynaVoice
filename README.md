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

Depois de autorizar o microfone no aplicativo principal, selecione um paciente fictício, inicie ou retome uma sessão e use **Abrir sobreposição de voz**. Autorize a exibição sobre outros aplicativos quando o Android solicitar. Uma bolha flutuante com microfone aparece na tela; ela pode ser arrastada e permanece sobre outro aplicativo do mesmo aparelho.

Toque na bolha para ditar. Ao terminar o reconhecimento, um painel temporário apresenta a frase transcrita e os campos editáveis de articulação, movimento, lado e força. Dados incompletos ou inválidos bloqueiam a confirmação. Somente **Confirmar** grava a medição no banco da sessão; **Fechar** descarta a captura. A frase original permanece registrada mesmo quando um campo é corrigido. Pressionar a bolha por mais tempo permite encerrar o assistente.

O teste manual em um Samsung Android 12 confirmou o ditado e a correção sobre a calculadora, usando dados fictícios. Também houve desconexão do serviço de voz em tentativas anteriores; reabrir o aplicativo permitiu continuar, mas não determina a causa nem garante que o problema não volte. [Roteiro e imagens](evidencias/2026-11-26-celular/README.md).

## Executar

Pré-requisitos: Flutter 3.44.8 ou compatível, Android SDK, um aparelho/emulador Android e um serviço de reconhecimento de fala com português do Brasil.

```powershell
git clone --branch codex/functional-voice-mvp --single-branch https://github.com/IgorEduss/DynaVoice.git
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
flutter drive -d <id-do-emulador> --driver=test_driver/integration_test.dart --target=integration_test/manual_android_test.dart
flutter build apk --debug
```

As capturas dos testes são gravadas em `build/evidencias/telas/`. Para usar outro diretório, defina a variável de ambiente `DYNAVOICE_EVIDENCIAS`.

Resultados da verificação anterior, registrados antes do teste no aparelho físico:

- análise estática sem apontamentos;
- 35 testes Dart/Flutter aprovados;
- 24 verificações SQLite/Python aprovadas e cinco consultas exportadas;
- um cenário Android de integração aprovado no Pixel 8 / Android 14, usando serviço de voz falso;
- APK de depuração gerado;
- relatório PDF de seis páginas e apresentação de 12 slides renderizados e inspecionados;
- quatro capturas e vídeo de 41 segundos do fluxo automatizado no emulador.

O cenário de integração cobre transcrição definitiva simulada, revisão, correção, confirmação única, encerramento da sessão, persistência após reabrir, histórico, estatísticas e exportação. Os testes de interface também cobrem transcrição parcial e cancelamento. Esses testes não comprovam a captura física do microfone.

A [verificação complementar de 26/11/2026](evidencias/2026-11-26/README.md) registra a correção do encerramento da sessão, o teste de entrada manual, seis capturas e os limites da tentativa de reconhecimento de voz no emulador.

A verificação posterior no aparelho físico incluiu a bolha sobre outro aplicativo, ditado real, correção de força e de articulação, confirmação e consulta dos registros. A análise estática e 38 testes Flutter também passaram. As evidências e os limites constam em [teste no celular](evidencias/2026-11-26-celular/README.md).

## Arquivos principais

- `lib/main.dart`: atendimento, estados de voz e revisão obrigatória.
- `lib/services/speech_recognition_service.dart`: interface e implementação Android.
- `lib/parser_service.dart`: entidades, números falados, unidades e ambiguidades.
- `lib/data/database.dart`: SQLite, migração para esquema v2 e transações.
- `lib/services/export_service.dart`: exportação JSON.
- `lib/overlay.dart`: bolha flutuante e revisão editável sobre outro aplicativo.
- `lib/services/overlay_coordinator.dart`: comunicação com a sessão e validação antes de gravar.
- `test/`: parser, persistência, serviço falso, widgets e overlay.
- `integration_test/app_test.dart`: fluxo completo reproduzível no Android.
- `integration_test/manual_android_test.dart`: entrada manual e revisão no Android.
- `sql/`: esquema, dados fictícios e consultas independentes.
- `evidencias/`: logs, banco demonstrativo, CSVs, capturas e vídeo.
- `docs/Relatorio_Nota2_DynaVoice.md`: relatório editável.
- `output/pdf/Relatorio_Nota2_DynaVoice.pdf`: relatório de uma versão anterior.
- `output/apresentacao/DynaVoice_Nota3_Atualizada.pptx`: apresentação atualizada.

`scripts/verificar_sql.py` recria somente `evidencias/dynavoice_demonstracao.db`. O teste Android usa `integration_test.db`, separado do banco normal do aplicativo.

## Limitações restantes

- O teste físico ocorreu em um aparelho e sobre a calculadora; o aplicativo real do dinamômetro e outras versões do Android não foram testados.
- O reconhecedor do Android pode ficar indisponível ou ser desconectado; sua precisão não é garantida e não foi feito teste controlado sem internet.
- O parser usa vocabulário controlado; campos ausentes ou ambíguos exigem correção humana.
- Não há autenticação, criptografia, backup ou sincronização.
- Não houve validação clínica, regulatória, de acessibilidade, desempenho ou uso com dados reais.
- O SDK emite avisos de futura atualização conjunta de Gradle, AGP e Kotlin; o build atual termina com sucesso.

As evidências registram somente os cenários realmente executados. A publicação no GitHub não substitui a entrega acadêmica no AVA.
