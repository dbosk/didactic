"""Writes cfg.json beside this file: the preamble of each configuration of the flows.

Only the configurations that the appendix's tables use are here; see README.md.
"""
import json, os

# Plain: no package, but its fonts and margins, so that a page holds the same text.
MIM = (r"\usepackage[T1]{fontenc}\usepackage[osf,sc]{mathpazo}\usepackage[scaled=0.90]{helvet}"
       r"\usepackage[scaled=0.85]{beramono}\setlrmarginsandblock{23mm}{60.2mm}{*}"
       r"\setulmarginsandblock{30mm}{48.5mm}{*}\checkandfixthelayout\setsecnumdepth{subsection}"
       r"\nouppercaseheads")
ART = r"\documentclass[a4paper,10pt,article,oneside,oldfontcommands]{memoir}"
NW = r"\usepackage{noweb}"
BC = r"\noweboptions{longxref,breakcode}"
MINTNW = r"\usepackage[minted]{noweb}\noweboptions{breakcode}"


def dd(options=""):
    return r"\usepackage[marginparmargin=outer%s]{didactic}" % options


cfg = {
    # noweb chunks.  Plain, without and with breakcode; the package, the same.
    "none": dict(pre=ART + MIM + NW),
    "bc": dict(pre=ART + MIM + NW + BC),
    "nn": dict(pre=ART + NW + dd()),
    "n": dict(pre=ART + NW + dd() + BC),
    "nG": dict(pre=ART + NW + dd(",keepmaxgap=0") + BC),
    # Chunks woven for minted (the tominted filter's form), always with breakcode.
    "mintp": dict(pre=ART + MIM + MINTNW, minted=True),
}
for name, options in [("m", ""), ("mL0", ",keeplines=0"), ("mG0", ",keepmaxgap=0"), ("mLead0", ",keepleadin=false")]:
    cfg[name] = dict(pre=ART + dd(options) + MINTNW, minted=True)

# The pair of club and widow penalties, on both kinds of chunk.  1001 tells a last line
# from a first one, for counting; its breaks are those of 1000.
PAIR = r"\AtBeginDocument{\clubpenalty=%d \csname @clubpenalty\endcsname=%d \widowpenalty=%d\relax}"
for s, (c, w) in {"A": (1000, 10000), "B": (10000, 10000), "W": (1000, 1001)}.items():
    cfg["n" + s] = dict(pre=ART + NW + dd() + BC + PAIR % (c, c, w))
    cfg["m" + s] = dict(pre=ART + dd() + MINTNW + PAIR % (c, c, w), minted=True)

# keepmaxgap and noweb's \nwdocspar apart.  The K ones are for a copy of the package with
# its \let\nwdocspar\relax taken out (v/kept/, see README.md): the limit on, the break
# kept.  The D ones: the limit off, the break dropped anyway.
DROP = r"\AtBeginDocument{\let\nwdocspar\relax}"
cfg["nK"] = dict(pre=ART + NW + dd() + BC)
cfg["mK"] = dict(pre=ART + dd() + MINTNW, minted=True)
cfg["nD"] = dict(pre=ART + NW + dd(",keepmaxgap=0") + BC + DROP)
cfg["mD"] = dict(pre=ART + dd(",keepmaxgap=0") + MINTNW + DROP, minted=True)

json.dump(cfg, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cfg.json"), "w"))
