# Small documents for the appendix on page breaks: one break, on a page of 20 lines.
# Run in an empty directory; it writes its documents there.
import subprocess,re
para=lambda tag,n: ' '.join(f'{tag}{i}xx word word word word word word word word word word word.' for i in range(n))
def build(name,pen,body,extra=''):
    src=r'''\documentclass{article}
\usepackage[paperheight=20cm,paperwidth=14cm,textheight=240pt,textwidth=10cm,top=2cm]{geometry}
\setlength{\parskip}{0pt}\setlength{\parindent}{0pt}\setlength{\topskip}{12pt}
\clubpenalty=%s \widowpenalty=%s
\flushbottom\pagestyle{empty}
%s
\begin{document}
%s
\end{document}
'''%(pen,pen,extra,body)
    open(name+'.tex','w').write(src)
    subprocess.run(['pdflatex','-interaction=nonstopmode',name+'.tex'],capture_output=True)
    t=subprocess.run(['pdftotext','-layout',name+'.pdf','-'],capture_output=True,text=True).stdout
    return t.split('\f')
def lines(n,tag='L'):
    return r'\par '.join(f'{tag}{i} short line' for i in range(n))+r'\par '
# page holds 240/12=20 lines. A: 19 single-line paragraphs, then a long paragraph whose first line lands on line 20.
long=' '.join(['word']*260)
for pen in (150,1000,9999,10000):
    p=build(f'orph{pen}',pen,lines(19)+long)
    first=[l for l in p[0].splitlines() if l.strip()]
    print('text-only orphan',pen,'lines on p1:',len(first),'last:',first[-1][:30])
for pen in (150,1000,9999,10000):
    p=build(f'orphs{pen}',pen,r'\setlength{\parskip}{0pt plus 2pt}'+lines(19)+long)
    first=[l for l in p[0].splitlines() if l.strip()]
    print('with stretch orphan',pen,'lines on p1:',len(first),'last:',first[-1][:30])
# Heading tests: section takes about 3-4 lines of space; vary filler.
for n in range(13,19):
    p=build(f'h{n}',150,lines(n)+r'\section*{Heading}'+'One line paragraph.\\par '+long)
    f=[l for l in p[0].splitlines() if l.strip()]
    print('heading+1-line-para filler',n,'p1 lines',len(f),'last:',f[-1].strip()[:28])
for n in range(13,19):
    p=build(f'g{n}',150,lines(n)+r'\section*{Heading}'+long)
    f=[l for l in p[0].splitlines() if l.strip()]
    print('heading+long-para filler',n,'p1 lines',len(f),'last:',f[-1].strip()[:28], 'heading on p1' if any('Heading' in x for x in f) else 'heading moved')
print('--- band test: stretch per paragraph')
for s in ('0.2','0.3','0.5','1'):
  for pen in (150,1000,9999):
    p=build(f'b{s.replace(".","")}{pen}',pen,r'\setlength{\parskip}{0pt plus %spt}'%s+lines(19)+long)
    first=[l for l in p[0].splitlines() if l.strip()]
    print('stretch',s,'pen',pen,'lines on p1:',len(first),'orphan stays' if len(first)==20 else 'orphan moved')
