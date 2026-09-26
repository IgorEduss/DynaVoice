from pathlib import Path
from PIL import Image as PILImage
from xml.sax.saxutils import escape
import json,re
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,PageBreak,Table,TableStyle,Preformatted,Image
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY,TA_CENTER
from reportlab.lib import colors
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
root=Path(__file__).resolve().parents[1]
log=(root/'evidencias/flutter_test.txt').read_text(encoding='utf-8-sig')
assert 'All tests passed!' in log
assert 'No issues found!' in (root/'evidencias/flutter_analyze.txt').read_text(encoding='utf-8-sig')
android=(root/'evidencias/integracao_android.txt').read_text(encoding='utf-8-sig')
assert 'All tests passed!' in android,'Aguardar integração Android.'
count=int(re.findall(r'\+(\d+): All tests passed!',log)[-1])
sql=json.loads((root/'evidencias/resultados_sql.json').read_text(encoding='utf-8'))
assert all(t['resultado']=='PASSOU' for t in sql['testes'])
for filename,name in [('times.ttf','TimesLocal'),('timesbd.ttf','TimesLocalBold')]:
 pdfmetrics.registerFont(TTFont(name,str(Path('C:/Windows/Fonts')/filename)))
body=ParagraphStyle('Body',fontName='TimesLocal',fontSize=12,leading=18,alignment=TA_JUSTIFY,spaceAfter=9)
small=ParagraphStyle('Small',parent=body,fontSize=10,leading=13,spaceAfter=5,alignment=0)
heading=ParagraphStyle('Heading',parent=body,fontName='TimesLocalBold',fontSize=12,leading=18,spaceBefore=8,spaceAfter=12,alignment=0)
title=ParagraphStyle('Title',parent=heading,fontSize=14,leading=20,alignment=TA_CENTER)
code=ParagraphStyle('Code',fontName='Courier',fontSize=9.5,leading=12.5,spaceAfter=10)
story=[];md=[]
def h(text):story.append(Paragraph(escape(text),heading));md.append('## '+text+'\n')
def para(text,style=body):story.append(Paragraph(escape(text),style));md.append(text+'\n')
def codeblock(text):story.append(Preformatted(text,code));md.append('```sql\n'+text+'\n```\n')
def table(headers,rows,widths):
 data=[[Paragraph(escape(str(v)),small) for v in row] for row in [headers]+rows]
 t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT');t.setStyle(TableStyle([
 ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#E8EEF3')),('VALIGN',(0,0),(-1,-1),'TOP'),
 ('LINEBELOW',(0,0),(-1,0),.7,colors.HexColor('#324C60')),('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#CBD5DC')),
 ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5)]));story.append(t);story.append(Spacer(1,10))
 md.append('| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+'\n'.join('| '+' | '.join(map(str,r))+' |' for r in rows)+'\n')
def page():story.append(PageBreak());md.append('\n<!-- quebra de página -->\n')
para('UNIVERSIDADE ESTADUAL DO MARANHÃO',title)
para('Curso Superior de Tecnologia em Análise e Desenvolvimento de Sistemas - Gestão da Qualidade e Teste de Software',small)
para('Anderson Silva da Cunha - Igor Eduardo da Silva Souza',small)
para('DYNAVOICE: DESENVOLVIMENTO, TESTES E MELHORIA DO MVP',title)
para('Nota 2 - Axixá - 2026',small)
h('1 INTRODUÇÃO')
para('O DynaVoice é uma proposta de aplicativo móvel destinada a fisioterapeutas para organizar registros de força obtidos por dinamometria. A Nota 1 estabeleceu requisitos de captura de voz, interpretação de comandos, revisão dos dados, persistência e exportação, além da hierarquia Paciente, Sessão, Avaliação e Medição. Esta etapa aperfeiçoou o protótipo Flutter, priorizando o armazenamento relacional e a validação dos registros, em correspondência com os critérios avaliativos da Nota 2.')
h('2 DESCRIÇÃO DO PROTÓTIPO/MVP')
para('A versão recebida já continha telas, um analisador textual baseado em expressões regulares e código de sobreposição Android. Entretanto, o histórico permanecia em memória, a entrada de voz era simulada por frases predefinidas e o JSON era apenas exibido. A versão aperfeiçoada cadastra pacientes, inicia e retoma sessões, revisa medições antes da gravação, consulta histórico e estatísticas e salva arquivos JSON.')
para('O reconhecimento de áudio permanece fora do escopo implementado. O aplicativo identifica a entrada manual e a simulação, sem apresentar exemplos predefinidos como fala reconhecida. Os dados empregados na validação são fictícios. Os resultados apresentados neste relatório decorrem da execução dos scripts e testes incluídos no projeto.')
page()
h('3 DESENVOLVIMENTO DA SOLUÇÃO')
para('A aplicação foi organizada em interface, parser, repositório SQLite e serviço de exportação. O código original foi preservado em docs/ para comparação. O esquema SQL distribuído com o aplicativo é o mesmo empregado na verificação independente, evitando divergência entre documentação e implementação.')
table(['Entidade','Responsabilidade e integridade'],[
['Paciente','PK id; nome obrigatório com 2 a 120 caracteres; data de criação válida.'],
['Sessão','PK id; FK paciente_id; início obrigatório; encerramento não anterior ao início.'],
['Avaliação','PK id; FK sessao_id; articulação e movimento controlados; UNIQUE por sessão, articulação e movimento.'],
['Medição','PK id; FK avaliacao_id; lado e origem controlados; força numérica; horário original e texto preservados.'],
],[3*cm,13*cm])
para('Relacionamentos: Paciente 1:N Sessão; Sessão 1:N Avaliação; Avaliação 1:N Medição. Articulação e movimento ficam na avaliação, evitando sua repetição nas medições. Cada tentativa registra lado e força. A exclusão de um paciente exige confirmação na interface e propaga-se às entidades dependentes por ON DELETE CASCADE.',small)
codeblock('''PRAGMA foreign_keys = ON;
CREATE TABLE medicao (
 id INTEGER PRIMARY KEY,
 avaliacao_id INTEGER NOT NULL
   REFERENCES avaliacao(id) ON DELETE CASCADE,
 lado TEXT NOT NULL CHECK(lado IN ('Direito','Esquerdo')),
 forca_kgf REAL NOT NULL CHECK(
   typeof(forca_kgf) IN ('integer','real')
   AND forca_kgf >= 0 AND forca_kgf <= 1000),
 ...
);''')
para('Trecho abreviado; o script completo é sql/01_schema.sql. A faixa de 0 a 1000 kgf é uma regra técnica do MVP, não um limite clínico validado. A gravação da avaliação e da medição ocorre em transação. O repositório rejeita novas medições em sessões encerradas.',small)
page()
h('3.1 DADOS DE TESTE E CONSULTAS SQL')
para('O script sql/02_dados_teste.sql insere 3 pacientes fictícios, 4 sessões, 6 avaliações e 12 medições. Carlos Mendes possui duas sessões comparáveis; Ana Beatriz e Ricardo Ferreira permitem verificar separação por paciente. O carregamento de demonstração na interface só é permitido em banco vazio.')
table(['Consulta','Informação produzida'],[
['Q1','Histórico com paciente, sessão, articulação, movimento, lado, força, horário e origem.'],
['Q2','Quantidade de tentativas, média e pico por avaliação e lado.'],
['Q3','Evolução do pico de flexão do joelho direito do paciente 1.'],
['Q4','Quantidade de sessões por paciente, incluindo pacientes sem sessão por LEFT JOIN.'],
['Q5','Picos direito e esquerdo por avaliação; ausência de lado resulta em NULL.'],
],[2*cm,14*cm])
codeblock('''SELECT s.iniciada_em, MAX(m.forca_kgf) AS pico_kgf
FROM medicao m
JOIN avaliacao a ON a.id=m.avaliacao_id
JOIN sessao s ON s.id=a.sessao_id
WHERE s.paciente_id=1 AND a.articulacao='Joelho'
 AND a.movimento='Flexão' AND m.lado='Direito'
GROUP BY s.id ORDER BY s.iniciada_em;''')
table(['Resultado verificado','Valor obtido'],[
['Média da flexão direita, primeira sessão','33,2 kgf (32,4 e 34,0; duas tentativas)'],
['Pico em 10/09/2026','34,0 kgf'],
['Pico em 20/09/2026','38,0 kgf'],
],[9*cm,7*cm])
para('Fonte: execução de sql/03_consultas.sql sobre o banco fictício. Os resultados completos estão em evidencias/consulta_1.csv a consulta_5.csv. A diferença entre os picos é descritiva e não demonstra evolução clínica real.',small)
page()
h('4 TESTES INICIAIS')
para(f'A validação combinou {len(sql["testes"])} verificações independentes em SQLite/Python, {count} testes automatizados Dart/Flutter e um teste de integração Android. O analisador estático terminou sem problemas. O ambiente utilizou Flutter 3.44.8, Dart 3.12.2 e emulador Android Pixel 8. Os registros de execução estão na pasta evidencias/.')
table(['Procedimento / resultado esperado','Resultado obtido'],[
['Criar esquema e inserir o conjunto fictício.','3 pacientes, 4 sessões, 6 avaliações e 12 medições; integridade do banco: ok.'],
['Tentar PK duplicada, FK inexistente, nome nulo/vazio, lado inválido e força negativa/textual.','Operações rejeitadas; conjunto válido preservado.'],
['Gravar, fechar e reabrir o banco.','Medições e sessões abertas recuperadas.'],
['Forçar falha na inserção após criar a avaliação.','Transação revertida; avaliação parcial não permaneceu.'],
['Interpretar 32,4; números por extenso; decimal com zero inicial.','Valores esperados reconhecidos; ausência de força distinguida de zero.'],
['Revisar, corrigir a força e confirmar; cancelar outra revisão.','Correção gravada; cancelamento não gerou medição.'],
['Exportar JSON do paciente 1.','Arquivo legível com IDs e horários originais; dados de outros pacientes excluídos.'],
['Executar fluxo Android e reabrir banco nativo.','12 registros iniciais; 13 após inclusão; 9 no JSON filtrado; registros recuperados após reabertura.'],
],[9.3*cm,6.7*cm])
para('Arquivos: flutter_analyze.txt, flutter_test.txt, testes_sql.txt, resultados_sql.json e integracao_android.txt. As contagens correspondem a verificações executadas, não a uma certificação de qualidade ou cobertura integral de caminhos.',small)
page()
h('5 FALHAS, BUGS E MELHORIAS')
table(['Problema identificado','Correção ou tratamento'],[
['Histórico apenas em memória.','SQLite integrado; sessões abertas podem ser retomadas.'],
['Timestamp alterado a cada exportação.','Horário capturado na criação do registro e preservado.'],
['Ausência de valor interpretada como zero.','Valor ausente é nulo; revisão exige preenchimento válido.'],
['Números negativos e pontuação mal interpretados.','Rejeição de negativos/entradas numéricas ambíguas; correção de pontuação e decimais por extenso.'],
['Registro sem conferência e JSON apenas em janela.','Confirmação e edição antes da gravação; exportação para arquivo.'],
],[7*cm,9*cm])
h('6 EVIDÊNCIAS DA ATIVIDADE')
imgs=[]
for name in ['02_revisao','03_historico']:
 image_path=root/f'evidencias/telas/{name}.png'
 w,hp=PILImage.open(image_path).size
 image=Image(str(image_path),width=w/hp*11.2*cm,height=11.2*cm)
 imgs.append(image)
story.append(Table([imgs],colWidths=[8*cm,8*cm]))
para('Figura 1 - Revisão antes da gravação e histórico persistido no emulador Android. Fonte: capturas obtidas durante o teste de integração, 25 set. 2026.',small)
md.append('![Revisão](../evidencias/telas/02_revisao.png)\n\n![Histórico](../evidencias/telas/03_historico.png)\n')
para('Os scripts SQL, o banco de demonstração, os CSVs e os testes acompanham o projeto. Não foi publicado repositório ou ambiente online nesta etapa.',small)
page()
h('7 LIMITAÇÕES E MELHORIAS PROPOSTAS')
para('A transcrição de áudio não foi integrada. O parser trabalha com vocabulário limitado, não resolve toda ambiguidade de linguagem natural e depende da revisão humana. A sobreposição é demonstrativa; seu comportamento entre aplicativos e versões Android exige validação adicional em aparelho físico. O teste Android cobre o fluxo interno de registros, não a captura de voz ou o compartilhamento por aplicativos externos.')
para('Não foram implementados autenticação, criptografia do banco, backup automático ou sincronização. O armazenamento local, por si só, não comprova conformidade legal nem segurança suficiente para uso clínico. O protótipo deve permanecer em avaliação com dados fictícios. Também não foram realizados ensaios de desempenho, acessibilidade ou validação clínica. A próxima etapa poderá integrar transcrição local e ampliar esses testes, preservando a revisão antes de salvar.')
h('8 CONCLUSÃO')
para('O aperfeiçoamento transformou o histórico volátil em persistência relacional organizada, com integridade referencial, transações, consultas úteis e exportação reproduzível. Os testes executados demonstraram o funcionamento dos cenários previstos e orientaram correções no tratamento numérico e no fluxo de gravação. O principal aprendizado foi relacionar requisitos, restrições de dados e evidências de execução, distinguindo funcionalidades implementadas de recursos ainda planejados. Assim, a Nota 2 avança o requisito de persistência da Nota 1 e mantém explícitos os limites do MVP.')
h('REFERÊNCIAS')
para('CUNHA, Anderson Silva da; SOUZA, Igor Eduardo da Silva. DynaVoice: análise da qualidade da proposta tecnológica para registro de aferições de força por voz. Axixá: UEMA, 2026. Relatório técnico da Nota 1.',small)
para('SQLITE. Foreign Key Support. Disponível em: https://www.sqlite.org/foreignkeys.html. Acesso em: 25 set. 2026.',small)
para('TEKARTIK. sqflite: SQLite plugin for Flutter. Disponível em: https://pub.dev/packages/sqflite. Acesso em: 25 set. 2026.',small)
para('FLUTTER. Integration testing. Disponível em: https://docs.flutter.dev/testing/integration-tests. Acesso em: 25 set. 2026.',small)
out=root/'output/pdf';out.mkdir(parents=True,exist_ok=True)
def footer(canvas,doc):
 canvas.setFont('TimesLocal',10);canvas.drawRightString(19*cm,28*cm,str(doc.page))
 canvas.setFont('TimesLocal',8);canvas.setFillColor(colors.HexColor('#66717B'));canvas.drawString(3*cm,1.3*cm,'DynaVoice | Nota 2 | Desenvolvimento, testes e melhoria do MVP')
doc=SimpleDocTemplate(str(out/'Relatorio_Nota2_DynaVoice.pdf'),pagesize=(21*cm,29.7*cm),leftMargin=3*cm,rightMargin=2*cm,topMargin=3*cm,bottomMargin=2*cm,title='DynaVoice - Nota 2',author='Anderson Silva da Cunha; Igor Eduardo da Silva Souza')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
(root/'docs/Relatorio_Nota2_DynaVoice.md').write_text('\n'.join(md),encoding='utf-8')
print(out/'Relatorio_Nota2_DynaVoice.pdf')
