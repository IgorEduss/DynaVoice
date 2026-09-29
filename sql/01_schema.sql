PRAGMA foreign_keys = ON;
CREATE TABLE paciente (
 id INTEGER PRIMARY KEY,
 nome TEXT NOT NULL CHECK(length(trim(nome)) BETWEEN 2 AND 120),
 criado_em TEXT NOT NULL CHECK(julianday(criado_em) IS NOT NULL)
);
CREATE TABLE sessao (
 id INTEGER PRIMARY KEY,
 paciente_id INTEGER NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
 iniciada_em TEXT NOT NULL CHECK(julianday(iniciada_em) IS NOT NULL),
 encerrada_em TEXT CHECK(encerrada_em IS NULL OR (julianday(encerrada_em) IS NOT NULL AND julianday(encerrada_em) >= julianday(iniciada_em)))
);
CREATE TABLE avaliacao (
 id INTEGER PRIMARY KEY,
 sessao_id INTEGER NOT NULL REFERENCES sessao(id) ON DELETE CASCADE,
 articulacao TEXT NOT NULL CHECK(articulacao IN ('Joelho','Ombro','Cotovelo','Quadril','Punho','Tornozelo')),
 movimento TEXT NOT NULL CHECK(movimento IN ('Flexão','Extensão','Abdução','Adução','Rotação Interna','Rotação Externa')),
 UNIQUE(sessao_id, articulacao, movimento)
);
CREATE TABLE medicao (
 id INTEGER PRIMARY KEY,
 avaliacao_id INTEGER NOT NULL REFERENCES avaliacao(id) ON DELETE CASCADE,
 lado TEXT NOT NULL CHECK(lado IN ('Direito','Esquerdo')),
 forca_kgf REAL NOT NULL CHECK(typeof(forca_kgf) IN ('integer','real') AND forca_kgf >= 0 AND forca_kgf <= 1000),
 registrada_em TEXT NOT NULL CHECK(julianday(registrada_em) IS NOT NULL),
 texto_original TEXT NOT NULL DEFAULT '',
 origem TEXT NOT NULL CHECK(origem IN ('manual','voz','simulacao'))
);
CREATE INDEX idx_sessao_paciente ON sessao(paciente_id);
CREATE INDEX idx_medicao_avaliacao ON medicao(avaliacao_id);
