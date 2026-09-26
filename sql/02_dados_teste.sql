-- Dados inteiramente fictícios. Executar apenas em banco vazio de demonstração.
INSERT INTO paciente VALUES (1,'Carlos Mendes','2026-09-01T08:00:00Z'),(2,'Ana Beatriz','2026-09-01T08:00:00Z'),(3,'Ricardo Ferreira','2026-09-01T08:00:00Z');
INSERT INTO sessao VALUES (1,1,'2026-09-10T09:00:00Z','2026-09-10T09:30:00Z'),(2,1,'2026-09-20T09:00:00Z','2026-09-20T09:30:00Z'),(3,2,'2026-09-20T10:00:00Z','2026-09-20T10:30:00Z'),(4,3,'2026-09-21T11:00:00Z','2026-09-21T11:30:00Z');
INSERT INTO avaliacao VALUES (1,1,'Joelho','Flexão'),(2,1,'Joelho','Extensão'),(3,2,'Joelho','Flexão'),(4,2,'Joelho','Extensão'),(5,3,'Ombro','Abdução'),(6,4,'Quadril','Adução');
INSERT INTO medicao VALUES
(1,1,'Direito',32.4,'2026-09-10T09:05:00Z','Flexão de joelho direito 32,4','simulacao'),
(2,1,'Direito',34.0,'2026-09-10T09:06:00Z','Flexão de joelho direito 34','simulacao'),
(3,1,'Esquerdo',30.0,'2026-09-10T09:07:00Z','Flexão de joelho esquerdo 30','simulacao'),
(4,2,'Direito',42.0,'2026-09-10T09:10:00Z','Extensão de joelho direito 42','simulacao'),
(5,3,'Direito',36.0,'2026-09-20T09:05:00Z','Flexão de joelho direito 36','simulacao'),
(6,3,'Direito',38.0,'2026-09-20T09:06:00Z','Flexão de joelho direito 38','simulacao'),
(7,3,'Esquerdo',35.0,'2026-09-20T09:07:00Z','Flexão de joelho esquerdo 35','simulacao'),
(8,4,'Direito',45.0,'2026-09-20T09:10:00Z','Extensão de joelho direito 45','simulacao'),
(9,5,'Direito',20.0,'2026-09-20T10:05:00Z','Abdução de ombro direito 20','simulacao'),
(10,5,'Esquerdo',18.0,'2026-09-20T10:06:00Z','Abdução de ombro esquerdo 18','simulacao'),
(11,6,'Direito',25.7,'2026-09-21T11:05:00Z','Adução de quadril direito 25,7','simulacao'),
(12,6,'Esquerdo',24.5,'2026-09-21T11:06:00Z','Adução de quadril esquerdo 24,5','simulacao');
