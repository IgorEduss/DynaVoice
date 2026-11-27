# Verificação complementar — 26/11/2026

Os testes foram feitos em um emulador com Android 14 e perfil Pixel 8, usando apenas pacientes e medições fictícios. A revisão inicial foi baseada no commit `09a2fd0e6e3d1ae41a2ad47061a372b1153dfb30` da ramificação `codex/functional-voice-mvp`.

## Resultados

- Análise estática sem apontamentos e 35 testes automatizados do projeto aprovados.
- 24 verificações SQL aprovadas, com cinco consultas exportadas.
- Fluxo no Android verificado com transcrição **simulada**: revisão, correção, confirmação, histórico, resultados, exportação e persistência após reabrir o banco.
- Entrada manual, revisão e gravação verificadas no Android em um cenário separado.
- APK de depuração compilado, instalado e aberto no emulador.

Ao encerrar uma sessão sem a sobreposição ativa, a interface da versão inicial permaneceu em carregamento. A chamada de fechamento da sobreposição não retornou nessa situação. A correção verifica se a sobreposição está ativa antes de fechá-la e limita o tempo de espera. Após a alteração, o teste de integração confirmou que a interface volta a ficar disponível ao encerrar a sessão.

## Limite do teste de voz

Foi tentado um teste com o serviço de reconhecimento Android e áudio sintético em português. O reconhecedor do emulador não informou suporte a português brasileiro, e o teste terminou antes de receber o áudio. O Android negou a alteração do idioma do sistema solicitada por comando. **Não há, nesta execução, validação de transcrição de áudio real.**

Continuam pendentes a captura de fala em aparelho físico e a validação da sobreposição entre aplicativos. O reconhecimento pode depender do serviço instalado e de conexão de rede.

## Capturas

As imagens foram feitas com a correção do encerramento aplicada. As duas imagens marcadas como voz simulada não comprovam captura por microfone.

1. [Atendimento e pacientes fictícios](01_atendimento.png).
2. [Revisão de transcrição simulada](02_revisao_voz_simulada.png).
3. [Histórico com registro de origem de voz simulada](03_historico_voz_simulada.png).
4. [Resultados descritivos](04_resultados.png).
5. [Entrada manual](05_entrada_manual.png).
6. [Revisão da entrada manual](06_revisao_manual.png).
