# Counts lone lines in generated documents, for the appendix on page breaks.
# Run in an empty directory: python3 pen.py <that directory> 300; output in pen-results.txt.
# Each row: (club, widow): [pages, orphans, widows].
import random,subprocess,re,sys,os
out=sys.argv[1]; os.chdir(out)
W='lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua enim minim veniam quis nostrud exercitation ullamco laboris nisi aliquip commodo consequat'.split()
def doc(seed,cls,club,widow,headevery):
    r=random.Random(seed); s=[]
    for i in range(int(sys.argv[2])):
        if headevery and i%headevery==0 and i: s.append(r'\section{Heading %d}'%i)
        n=r.randint(25,140)
        s.append('Qs '+' '.join(r.choice(W) for _ in range(n))+' Qe\n')
    return cls+r'''
\pagestyle{empty}
\makeatletter\AtBeginDocument{\clubpenalty=%d \@clubpenalty=%d \widowpenalty=%d}\makeatother
\begin{document}
'''%(club,club,widow)+'\n'.join(s)+'\n\\end{document}\n'
def stats(name):
    subprocess.run(['pdflatex','-interaction=nonstopmode',name+'.tex'],capture_output=True)
    t=subprocess.run(['pdftotext','-layout',name+'.pdf','-'],capture_output=True,text=True).stdout
    pages=[[l.strip() for l in p.splitlines() if l.strip()] for p in t.split('\f') if p.strip()]
    orph=sum(1 for p in pages if p[-1].startswith('Qs') and not p[-1].endswith('Qe'))
    wid=0
    for p in pages[1:]:
        if p[0].endswith('Qe') and not p[0].startswith('Qs'): wid+=1
    breaks=[p[-1][:30] for p in pages]
    return len(pages),orph,wid,breaks
CL={'memoir':r'\documentclass[a4paper,10pt,oneside]{memoir}\usepackage{lmodern}','article':r'\documentclass[a4paper,10pt]{article}'}
for cn,cls in CL.items():
 for he in (8,0):
  tot={}
  for seed in range(6):
    br={}
    for club,widow in [(150,150),(500,500),(1000,1000),(150,10000),(1000,10000),(10000,10000)]:
        name=f'{cn}{he}s{seed}c{club}w{widow}'
        open(name+'.tex','w').write(doc(seed,cls,club,widow,he))
        p,o,w,b=stats(name)
        a=tot.setdefault((club,widow),[0,0,0]); a[0]+=p;a[1]+=o;a[2]+=w
        br[(club,widow)]=b
    d=sum(1 for x,y in zip(br[(150,10000)],br[(1000,10000)]) if x!=y)
    tot.setdefault('diffpages',[0])[0]+=d
  print(cn,'heading every',he,{k:v for k,v in tot.items()})
