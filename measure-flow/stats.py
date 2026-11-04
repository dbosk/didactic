#!/usr/bin/env python3
import re,sys,collections
P=sys.path[0]
def stat(name):
    log=open(f'{P}/r/{name}/t.log',errors='replace').read()
    parts=re.split(r'^SEED (\S+)$',log,flags=re.M)
    es=[];pc=collections.Counter(); big=[]; und=len(re.findall(r'Underfull \\vbox',log)); over=len(re.findall(r'Overfull \\vbox',log))
    for i in range(1,len(parts),2):
        pgs=re.findall(r'PAGE (\d+) penalty=(-?\d+) goal=([\d.]+)pt\s*natural=([\d.]+)pt',parts[i+1])
        if not pgs: continue
        for p,pen,g,nat in pgs[:-1]:
            e=(float(g)-float(nat))/12
            es.append(e); pc[int(pen)]+=1
            if e>=2: big.append((round(e,1),int(pen)))
    es.sort(); n=len(es)
    q=lambda f:es[min(n-1,int(f*n))]
    cnt=lambda t:sum(1 for e in es if e>=t)
    pens=collections.defaultdict(list)
    for e,pen in big: pens[pen].append(e)
    print(f"{name}: pages={n} mean={sum(es)/n:.2f} median={q(.5):.1f} p90={q(.9):.1f} max={es[-1]:.1f} lines ({es[-1]*12:.0f}pt) >=1:{cnt(1)} >=2:{cnt(2)} >=3:{cnt(3)} >=5:{cnt(5)} >=10:{cnt(10)} >=20:{cnt(20)} U={und} O={over}")
    print('   break penalties:',dict(pc.most_common(7)))
    print('   gaps>=2 by penalty:',{k:(len(v),max(v)) for k,v in sorted(pens.items())})
for n in sys.argv[1:]: stat(n)
