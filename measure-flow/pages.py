#!/usr/bin/env python3
# pages per seed and lone lines by break penalty
import re,sys,json
P=sys.path[0]
def stat(name):
    log=open(f'{P}/r/{name}/t.log',errors='replace').read()
    parts=re.split(r'^SEED (\S+)$',log,flags=re.M)
    pp=[];pen=[]
    for i in range(1,len(parts),2):
        if parts[i]=='END': continue
        pg=re.findall(r'PAGE (\d+) penalty=(-?\d+) goal=',parts[i+1])
        pp.append(len(set(x[0] for x in pg)))
        pen+= [int(x[1]) for x in pg[:-1]]
    orph=sum(1 for p in pen if p in(1000,1100)); wid=sum(1 for p in pen if p in (1001,1101)); both=sum(1 for p in pen if p in (2001,2101))
    return pp,sum(pp),orph,wid,both,pen
if __name__=='__main__':
    for n in sys.argv[1:]:
        pp,t,o,w,b,_=stat(n); print(n,'total',t,'per seed',pp,'club',o,'widow',w,'both',b)
