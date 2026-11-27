# Teste em aparelho físico — 26/11/2026

## Ambiente

- Aparelho Samsung SM-F415F, Android 12, conectado por USB para instalação e registro das imagens.
- Aplicativo Android de depuração, com paciente e medições fictícios.
- A calculadora do mesmo aparelho serviu como aplicativo de fundo. O software do dinamômetro não estava disponível.
- Não foi realizado teste controlado sem internet nem medição da taxa de acerto.

## Ditado, correção e confirmação

Foi selecionado o paciente fictício Carlos Mendes e retomada a sessão de teste. O participante abriu a bolha flutuante, acessou a calculadora e ditou medições reais ao microfone do aparelho. O painel de conferência apareceu sobre a calculadora, sem salvar automaticamente.

Em um caso, a transcrição foi “extensão de punho direito 20 kg” e o participante editou a força para 22 kgf antes da confirmação. O banco foi consultado: o valor salvo é 22 kgf e o texto original de 20 kg foi preservado.

Em outro caso, o reconhecedor transcreveu “abdução de quadro esquerdo 22 kg”, sem identificar uma articulação válida. O botão de confirmação permaneceu desabilitado. O participante selecionou **Quadril**, conferiu os demais campos e confirmou. A consulta ao banco mostrou **Quadril / Abdução / Esquerdo / 22 kgf**, origem voz, mantendo a transcrição original. Esse caso demonstra a correção humana de uma transcrição incorreta; não demonstra reconhecimento perfeito.

## Imagens

1. [Bolha de microfone sobre a calculadora](01_microfone_calculadora.png).
2. [Conferência com articulação ausente e confirmação bloqueada](02_conferencia_incompleta.png).
3. [Articulação corrigida antes da confirmação](03_conferencia_corrigida.png).
4. [Desconexão do serviço de voz em versão intermediária](04_desconexao_voz.png).

As imagens são capturas do aparelho sem dados reais de pacientes. A imagem 4 registra uma tentativa anterior à inclusão dos campos editáveis; a mensagem de erro da versão posterior foi simplificada.

## Resultado e limitações

- O reconhecimento pela bolha, a revisão, a alteração de força e a seleção de uma articulação ausente foram exercitados no aparelho físico; as medições corrigidas foram confirmadas no banco local.
- Em duas tentativas anteriores o reconhecedor retornou `error_server_disconnected`. Após fechar e reabrir o aplicativo, o teste pôde prosseguir. A causa não foi determinada e a recorrência não está descartada.
- Não houve ensaio com o programa real do dinamômetro, verificação de funcionamento offline, avaliação clínica ou teste em outros aparelhos.
- A análise estática passou sem apontamentos e 38 testes automatizados Flutter passaram na versão com campos editáveis. Esses testes usam serviços simulados para os cenários de voz.
