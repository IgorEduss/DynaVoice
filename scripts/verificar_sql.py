"""Recria um banco de evidências isolado; não acessa o banco usado pelo aplicativo."""
from pathlib import Path
import sqlite3, json, csv, platform
root=Path(__file__).resolve().parents[1]
out=root/'evidencias';out.mkdir(exist_ok=True)
path=out/'dynavoice_demonstracao.db'
if path.exists():path.unlink()
db=sqlite3.connect(path)
db.row_factory=sqlite3.Row
db.executescript((root/'sql/01_schema.sql').read_text(encoding='utf-8'))
db.executescript((root/'sql/02_dados_teste.sql').read_text(encoding='utf-8'))
checks=[]
def check(name,condition):
 checks.append({'teste':name,'resultado':'PASSOU' if condition else 'FALHOU'})
 if not condition:raise AssertionError(name)
check('FK ativada',db.execute('PRAGMA foreign_keys').fetchone()[0]==1)
for table,count in {'paciente':3,'sessao':4,'avaliacao':6,'medicao':12}.items():check('Quantidade '+table,db.execute('SELECT COUNT(*) FROM '+table).fetchone()[0]==count)
invalid={
 'PK duplicada':"INSERT INTO paciente VALUES(1,'Duplicado','2026-09-25')",
 'Nome obrigatório':"INSERT INTO paciente(nome,criado_em) VALUES(NULL,'2026-09-25')",
 'Nome vazio':"INSERT INTO paciente(nome,criado_em) VALUES(' ','2026-09-25')",
 'Data inválida':"INSERT INTO paciente(nome,criado_em) VALUES('Paciente','inválida')",
 'Sessão sem paciente':"INSERT INTO sessao(paciente_id,iniciada_em) VALUES(999,'2026-09-25')",
 'Avaliação sem sessão':"INSERT INTO avaliacao(sessao_id,articulacao,movimento) VALUES(999,'Joelho','Flexão')",
 'Medição sem avaliação':"INSERT INTO medicao(avaliacao_id,lado,forca_kgf,registrada_em,origem) VALUES(999,'Direito',30,'2026-09-25','manual')",
 'Avaliação duplicada':"INSERT INTO avaliacao(sessao_id,articulacao,movimento) VALUES(1,'Joelho','Flexão')",
 'Força negativa':"UPDATE medicao SET forca_kgf=-1 WHERE id=1",
 'Força textual':"UPDATE medicao SET forca_kgf='abc' WHERE id=1",
 'Lado inválido':"UPDATE medicao SET lado='Inválido' WHERE id=1",
 'Origem inválida':"UPDATE medicao SET origem='voz' WHERE id=1",
 'Encerramento anterior ao início':"UPDATE sessao SET encerrada_em='2026-01-01' WHERE id=1"
}
for name,sql in invalid.items():
 try:db.execute(sql)
 except sqlite3.IntegrityError:check(name,True)
 else:check(name,False)
db.rollback()
queries=(root/'sql/03_consultas.sql').read_text(encoding='utf-8')
queries='\n'.join(l for l in queries.splitlines() if not l.strip().startswith('--'))
results={}
for i,sql in enumerate(filter(str.strip,queries.split(';')),1):
 rows=[dict(r) for r in db.execute(sql)]
 results['Q'+str(i)]=rows
 with (out/f'consulta_{i}.csv').open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
check('Evolução do pico de flexão direita: 34 para 38 kgf',[r['pico_kgf'] for r in results['Q3']]==[34,38])
check('Média da primeira avaliação direita: 33,2 kgf',results['Q2'][0]['media_kgf']==33.2)
check('Sem violações referenciais',not list(db.execute('PRAGMA foreign_key_check')))
check('Integridade física do banco',db.execute('PRAGMA integrity_check').fetchone()[0]=='ok')
db.close()
db=sqlite3.connect(path)
check('Persistência após reabrir',db.execute('SELECT COUNT(*) FROM medicao').fetchone()[0]==12)
db.close()
result={'python':platform.python_version(),'sqlite':sqlite3.sqlite_version,'testes':checks,'consultas':results}
(out/'resultados_sql.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'testes_sql.txt').write_text('\n'.join(f"{r['resultado']}: {r['teste']}" for r in checks)+f'\nTOTAL: {len(checks)} testes aprovados\n',encoding='utf-8')
print(f'{len(checks)} verificações SQL aprovadas; 5 consultas exportadas.')
