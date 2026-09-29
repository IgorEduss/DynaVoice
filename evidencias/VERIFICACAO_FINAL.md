# Verificação final — 29/09/2026

## Ambiente e comandos

- Flutter 3.44.8 e Dart 3.12.2.
- Emulador Pixel 8, Android 14 / API 34.
- Nenhum aparelho Android físico apareceu em `flutter devices` nesta execução.
- `flutter analyze`: aprovado, sem apontamentos.
- `flutter test --reporter expanded`: 35 testes aprovados.
- `python scripts/verificar_sql.py`: 24 verificações aprovadas e cinco CSVs gerados.
- `flutter drive ... integration_test/app_test.dart`: um cenário aprovado com serviço de voz falso.
- `flutter build apk --debug`: APK gerado com sucesso.

Logs: `flutter_analyze.txt`, `flutter_test.txt`, `testes_sql.txt`, `integracao_android.txt` e `build_android.txt`.

## Matriz de aceite

| Cenário | Evidência desta execução | Situação |
|---|---|---|
| Solicitar permissão do microfone | Manifesto Android, inicialização do serviço e estados testáveis | Implementado; confirmação visual em aparelho físico pendente |
| Microfone captar fala real | Implementação Android usa o reconhecedor do sistema em `pt_BR` | Pendente por ausência de aparelho físico |
| Mostrar transcrição | Resultado parcial e definitivo demonstrados com serviço falso no teste Android | Aprovado no fluxo; hardware pendente |
| Frase válida produzir Joelho/Flexão/Direito/32,4 | Testes do parser, widget e captura `02_revisao.png` | Aprovado |
| Frase incompleta não ser salva | Teste de widget bloqueia confirmação com campo ausente | Aprovado |
| Permitir correção | Revisão editável e cenário de integração | Aprovado |
| Cancelar revisão não criar medição | Teste de widget e integração | Aprovado |
| Confirmar criar uma única medição | Consulta ao banco após confirmação | Aprovado |
| Persistir após reabrir | Banco fechado e reaberto no cenário Android | Aprovado |
| Histórico e resultados refletirem a medição | Capturas `03_historico.png` e `04_resultados.png` | Aprovado |
| Entrada manual continuar funcionando | Teste de widget do fluxo manual | Aprovado |
| Tratar indisponibilidade do reconhecedor | Estado `indisponível`, mensagem de erro e alternativa manual | Implementado |
| Testes existentes e novos passarem | 35 Flutter + 24 SQL + 1 cenário Android | Aprovado |
| Funcionar em aparelho Android real | Não havia hardware conectado | Pendente |
| Não incluir credenciais ou dados de pacientes reais | Dados demonstrativos fictícios; varredura final do repositório | Aprovado, sujeito à revisão acadêmica dos nomes de autoria |

## Evidências visuais

- `telas/01_atendimento.png`: atendimento e pacientes fictícios.
- `telas/02_revisao.png`: transcrição e revisão editável.
- `telas/03_historico.png`: medição persistida com origem voz.
- `telas/04_resultados.png`: estatísticas após a confirmação.
- `video/dynavoice_fluxo_integrado.mp4`: demonstração de 41 segundos do fluxo automatizado no emulador.

O vídeo e as capturas usam `FakeSpeechRecognitionService`; não devem ser apresentados como prova de captura acústica real.

## Roteiro pendente para aparelho físico

1. Conectar o aparelho por USB, autorizar depuração e confirmar em `flutter devices`.
2. Executar `flutter run -d <id>` e selecionar um paciente fictício.
3. Iniciar sessão, tocar em **Ditar em pt-BR** e conceder o microfone.
4. Falar a frase de referência e registrar os estados pronto, ouvindo, processando e resultado.
5. Corrigir um campo, cancelar uma revisão e confirmar outra; verificar que somente a confirmação cria medição.
6. Encerrar e reabrir o aplicativo; conferir histórico, resultados e exportação.
7. Autorizar a sobreposição, ditar sobre outro aplicativo, retornar ao DynaVoice e revisar antes de salvar.
8. Repetir com reconhecimento indisponível ou permissão negada, confirmando a alternativa manual.

## Limites honestos

O reconhecimento real está integrado ao código, mas não foi validado em hardware nesta execução. O serviço falso torna os testes reproduzíveis e não mede precisão do reconhecedor. O overlay teve comunicação e cancelamento verificados automaticamente, não o comportamento completo entre aplicativos reais. Não há alegação de eficácia clínica, conformidade regulatória, segurança para dados reais ou reconhecimento perfeito.
