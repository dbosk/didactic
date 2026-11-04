import json
MIM=r"\usepackage[T1]{fontenc}\usepackage[osf,sc]{mathpazo}\usepackage[scaled=0.90]{helvet}\usepackage[scaled=0.85]{beramono}\setlrmarginsandblock{23mm}{60.2mm}{*}\setulmarginsandblock{30mm}{48.5mm}{*}\checkandfixthelayout\setsecnumdepth{subsection}\nouppercaseheads"
ART=r"\documentclass[a4paper,10pt,article,oneside,oldfontcommands]{memoir}"
NW=r"\usepackage{noweb}"; BC=r"\noweboptions{longxref,breakcode}"; DD=r"\usepackage[marginparmargin=outer%s]{didactic}"
def dd(x=''): return DD%x
cfg={
 'none':dict(pre=ART+MIM+NW),
 'bc':dict(pre=ART+MIM+NW+BC),
 'noneeb':dict(pre=ART+NW+dd()),
 'bc77':dict(pre=ART+NW+dd()+BC),
 'bceb':dict(pre=ART+NW+dd()+BC),
 'bcebG':dict(pre=ART+NW+dd(',keepmaxgap=0')+BC),
 'bcebL':dict(pre=ART+NW+dd(',keepleadin=false')+BC),
 'bcebH':dict(pre=ART+NW+dd(',keepafterheading=0')+BC),
 'bceb0':dict(pre=ART+NW+dd(',keepleadin=false,keepafterheading=0,keepmaxgap=0')+BC),
 'bcebNoD':dict(pre=ART+NW+dd()+BC+r"\AtBeginDocument{\def\nwdocspar{\@nwsemifilbreak{0.2in}}}"),
 'bctwo':dict(pre=r"\documentclass[a4paper,10pt]{memoir}"+MIM+NW+BC),
}
cfg['bcebk2']=dict(pre=ART+NW+dd(',keepafterheading=2')+BC)
K2=dd(',keepafterheading=2')
cfg['k2_1000']=dict(pre=ART+NW+K2+BC)
cfg['k2_A']=dict(pre=ART+NW+K2+BC)
cfg['bceb1000']=dict(pre=ART+NW+dd()+BC)
MINTNW=r"\usepackage[minted]{noweb}\noweboptions{breakcode}"
cfg['mintp']=dict(pre=ART+MIM+MINTNW,minted=True)
cfg['mintk2']=dict(pre=ART+K2+MINTNW,minted=True)
cfg['mintk2A']=dict(pre=ART+K2+MINTNW,minted=True)
cfg['mintk21000']=dict(pre=ART+K2+MINTNW,minted=True)

for n,o in [('m','') ,('mL0',',keeplines=0'),('mG0',',keepmaxgap=0'),('mLead0',',keepleadin=false'),('mH0',',keepafterheading=0'),('mAll0',',keeplines=0,keepmaxgap=0,keepleadin=false,keepafterheading=0')]:
    cfg[n]=dict(pre=ART+dd(o)+MINTNW,minted=True)
cfg['n']=dict(pre=ART+NW+dd()+BC)

cfg['nG']=dict(pre=ART+NW+dd(',keepmaxgap=0')+BC)
cfg['nn']=dict(pre=ART+NW+dd())
cfg['nG']=dict(pre=ART+NW+dd(',keepmaxgap=0')+BC)
cfg['nn']=dict(pre=ART+NW+dd())
# The pair of club and widow penalties, on both kinds of chunk.  1001 tells a last line
# from a first one, for counting; its breaks are those of 1000.
PAIR=r"\AtBeginDocument{\clubpenalty=%d \csname @clubpenalty\endcsname=%d \widowpenalty=%d\relax}"
for s,(c,w) in {'A':(1000,10000),'B':(10000,10000),'W':(1000,1001)}.items():
    cfg['n'+s]=dict(pre=ART+NW+dd()+BC+PAIR%(c,c,w))
    cfg['m'+s]=dict(pre=ART+dd()+MINTNW+PAIR%(c,c,w),minted=True)
json.dump(cfg,open('cfg.json','w'))
