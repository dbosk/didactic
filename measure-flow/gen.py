#!/usr/bin/env python3
import sys,json,random
out,cfgf,name=sys.argv[1:4]
c=json.load(open(cfgf))[name]
o=[c["pre"],r"\usepackage{lipsum}",r"""\makeatletter
\AtBeginDocument{\output\expandafter{\expandafter\mymeasure\the\output}}
\newcommand\mymeasure{\ifnum\outputpenalty>-10001 {\setbox0\vbox{\unvcopy255}\typeout{PAGE \the\c@page\space penalty=\the\outputpenalty\space goal=\the\ht255\space natural=\the\dimexpr\ht0+\dp0\relax\space end}}\fi}
\makeatother""",r"\begin{document}"]
SEEDS=12
for seed in range(SEEDS):
    R=random.Random(1000+seed)
    o.append(r"\clearpage\typeout{SEED %d}"%seed)
    o.append(r"\vspace*{%dpt}"%R.randrange(0,120))
    o.append(r"\section{Start%d}"%seed)
    o.append(r"\lipsum[1][1-3]")
    o.append("")
    for seg in range(60):
        b=R.random()
        n=R.randint(2,3) if b<.44 else R.randint(4,8) if b<.71 else R.randint(9,15) if b<.85 else R.randint(16,30) if b<.95 else R.randint(31,50)
        o.append(r"\nwenddocs{}\nwbegincode{2}\moddef{name}\endmoddef\nwstartdeflinemarkup\nwenddeflinemarkup")
        if c.get('minted'):
            o.append(r"\catcode37=14\relax\catcode126=13\relax\catcode36=3\relax\catcode38=4\relax\catcode35=6\relax\catcode94=7\relax\catcode95=8\relax\catcode13=5\relax\partopsep=0pt\relax\begin{minted}[xleftmargin=\codemargin,vspace=0pt,escapeinside=||]{python}")
        for i in range(n): o.append(f"code line {i}")
        if c.get('minted'): o.append(r"\end{minted}")
        alone=R.random()<.73
        o.append(r"\nwnotused{name}\nwendcode{}\nwbegindocs{3}"+(r"\nwdocspar" if alone else ""))
        if R.random()<.12: o.append(r"\section{H%d}"%seg)
        p=R.randint(1,4)
        o.append(r"\lipsum[%d][1-%d]"%(R.randint(1,20),p))
        o.append("")
o+=[r"\clearpage\typeout{SEED END}",r"\end{document}"]
open(out,"w").write("\n".join(o)+"\n")
