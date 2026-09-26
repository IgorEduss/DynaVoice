-- Q1: histórico completo com rastreabilidade por paciente, sessão e avaliação.
SELECT p.nome, s.id AS sessao_id, a.articulacao, a.movimento, m.lado,
       m.forca_kgf, m.registrada_em, m.origem
FROM medicao m JOIN avaliacao a ON a.id=m.avaliacao_id
JOIN sessao s ON s.id=a.sessao_id JOIN paciente p ON p.id=s.paciente_id
ORDER BY m.registrada_em, m.id;
-- Q2: estatísticas por avaliação e lado, sem misturar movimentos.
SELECT p.nome, s.id AS sessao_id, a.articulacao, a.movimento, m.lado,
 COUNT(*) AS tentativas, ROUND(AVG(m.forca_kgf),2) AS media_kgf, MAX(m.forca_kgf) AS pico_kgf
FROM medicao m JOIN avaliacao a ON a.id=m.avaliacao_id
JOIN sessao s ON s.id=a.sessao_id JOIN paciente p ON p.id=s.paciente_id
GROUP BY a.id,m.lado ORDER BY p.id,s.id,a.id,m.lado;
-- Q3: evolução do pico de flexão de joelho direito do paciente 1.
SELECT s.iniciada_em, MAX(m.forca_kgf) AS pico_kgf
FROM medicao m JOIN avaliacao a ON a.id=m.avaliacao_id JOIN sessao s ON s.id=a.sessao_id
WHERE s.paciente_id=1 AND a.articulacao='Joelho' AND a.movimento='Flexão' AND m.lado='Direito'
GROUP BY s.id ORDER BY s.iniciada_em;
-- Q4: contagem de sessões; LEFT JOIN também inclui pacientes sem atendimento.
SELECT p.id,p.nome,COUNT(s.id) AS sessoes FROM paciente p LEFT JOIN sessao s ON s.paciente_id=p.id GROUP BY p.id ORDER BY p.id;
-- Q5: comparação descritiva bilateral por avaliação, sem interpretação diagnóstica.
SELECT a.id AS avaliacao_id, a.articulacao,a.movimento,
 MAX(CASE WHEN m.lado='Direito' THEN m.forca_kgf END) AS pico_direito,
 MAX(CASE WHEN m.lado='Esquerdo' THEN m.forca_kgf END) AS pico_esquerdo
FROM avaliacao a JOIN medicao m ON m.avaliacao_id=a.id GROUP BY a.id ORDER BY a.id;
