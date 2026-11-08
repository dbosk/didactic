# Small documents for the appendix on page breaks: one break, on a page of 20 lines.
# Run in an empty directory; it writes its documents there.
import subprocess
long=' '.join(['word']*260)
lines=lambda n:r'\par '.join(f'L{i} short line' for i in range(n))+r'\par '
def build(name,body,pre=''):
    src=r'''\documentclass[oneside]{memoir}
\setstocksize{20cm}{14cm}\settrimmedsize{20cm}{14cm}{*}\settypeblocksize{240pt}{10cm}{*}\setlrmargins{*}{*}{1}\setulmargins{2cm}{*}{*}\setheadfoot{0pt}{0pt}\setheaderspaces{*}{0pt}{*}\checkandfixthelayout
\setlength{\parskip}{0pt}\setlength{\parindent}{0pt}\pagestyle{empty}\flushbottom
%s
\begin{document}
%s
\end{document}
'''%(pre,body)
    open(name+'.tex','w').write(src)
    subprocess.run(['pdflatex','-interaction=nonstopmode',name+'.tex'],capture_output=True)
    return subprocess.run(['pdftotext','-layout',name+'.pdf','-'],capture_output=True,text=True).stdout.split('\f')
for n in range(13,19):
    for kind,b in (('1line',r'\section*{Heading}One line paragraph.\par '+long),('long',r'\section*{Heading}'+long)):
        p=build(f'm{n}{kind}',lines(n)+b)
        f=[l for l in p[0].splitlines() if l.strip()]
        print(kind,n,'p1',len(f),'last',f[-1].strip()[:24])
import re
print(subprocess.run(['grep','-c','clubpenalty','m13long.log'],capture_output=True,text=True).stdout.strip())
p=build('mo',lines(19)+long)
f=[l for l in p[0].splitlines() if l.strip()]; print('text-only orphan memoir default p1',len(f),f[-1].strip()[:24])
