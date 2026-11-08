#!/usr/bin/env python3
"""The tables, from the saved results.  Refuses a row that isn't a result."""
import collections, json, os, re
from lib import PAPER, args

a, docs = args(__doc__, ("--context", dict(action="store_true", help="the text around each parted list")))
R = lambda s, d, e: os.path.join(a.work, a.tag, s, d.name + e)
have = lambda s, d: os.path.exists(R(s, d, ".json"))
sett = [s for s in ["noprobe", "pair-1000-1001"] + PAPER if any(have(s, d) for d in docs)]
for s in sett:
    for d in docs:
        if have(s, d):
            st = json.load(open(R(s, d, ".json")))
            if not st["ok"]:
                raise SystemExit(f"{s} / {d.name} isn't a result: {st}")
kind = {d.name: d.kind for d in docs}


def lp(s, d):
    P, L, G = {}, [], {}
    for l in open(R(s, d, ".lp"), errors="replace"):
        t = l.split()
        if t and t[0] == "P" and len(t) == 3:
            P[int(t[1])] = int(t[2])
        elif t and t[0] == "L" and len(t) == 7:
            L.append(dict(id=int(t[1]), para=int(t[2]), typ=t[3], depth=int(t[4]), nb=int(t[5]), page=int(t[6])))
        elif t and t[0] == "G" and len(t) == 6:
            G[int(t[1])] = (int(t[2]), float(t[3][:-2]), float(t[4][:-2]), float(t[5][:-2]))
    if len({g[3] for g in G.values()}) > 1:
        raise SystemExit(f"{d.name}, {s}: the unit of a line varies between pages: an old probe?")
    return P, L, G


def parted(s, d):
    P, L, G = lp(s, d)
    out = []
    for l in L:
        if l["nb"] or l["para"] not in P or P[l["para"]] == l["page"]:
            continue
        g = G.get(P[l["para"]])
        out.append(dict(l, ppage=P[l["para"]], e=(g[1] - g[2]) / g[3] if g else None))
    return out


def words(s, d):
    return [sorted(x.split()) for x in open(R(s, d, ".txt"), errors="replace").read().split("\f")]


def diff(s, t, d):
    x, y = words(s, d), words(t, d)
    return sum(p != q for p, q in zip(x, y)) + abs(len(x) - len(y))


def table(head, rows):
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for r in rows:
        print("| " + " | ".join(str(c) for c in r) + " |")
    print()


print("## Pages\n")
rows = []
tot = collections.Counter()
for d in docs:
    row = [d.name, kind[d.name]]
    for s in sett:
        n = json.load(open(R(s, d, ".json")))["pages"] if have(s, d) else "-"
        row.append(n)
        if n != "-":
            tot[s] += n
    rows.append(row)
rows.append(["total", ""] + [tot[s] for s in sett])
table(["document", "kind"] + sett, rows)

print("## Gaps (empty lines at the foot of logged text pages)\n")
rows = []
for s in sett:
    if not all(os.path.exists(R(s, d, ".lp")) for d in docs if have(s, d)):
        continue
    e = []
    for d in docs:
        if have(s, d):
            e += [(g[1] - g[2]) / g[3] for g in lp(s, d)[2].values()]
    rows.append([s, len(e), sum(x >= 3 for x in e), sum(x >= 5 for x in e), sum(x > 5 for x in e), f"{max(e):.1f}"])
table(["setting", "logged", "e>=3", "e>=5", "e>5", "largest"], rows)

print("## Lone lines (from the penalty each page broke at)\n")
print("1000/1000 is read from pair-1000-1001, whose widow penalty tells them apart.\n")
rows = []
FIRST, LAST, BOTH = {1000, 1100}, {1001, 1101}, {2001, 2101}
for s, label in [("pair-1000-1001", "1000/1000"), ("pair-1000-10000", "1000/10000"), ("pair-10000-10000", "10000/10000")]:
    f = l = 0
    for d in docs:
        if have(s, d):
            pens = [g[0] for g in lp(s, d)[2].values()]
            f += sum(p in FIRST or p in BOTH for p in pens)
            l += sum(p in LAST or p in BOTH for p in pens)
    rows.append([label, f, l])
table(["pair", "first line alone at the foot", "last line alone at the top"], rows)
same = [d.name for d in docs if have("current", d) and have("pair-1000-1001", d) and diff("current", "pair-1000-1001", d)]
print("pair-1000-1001 has other words on a page than current in:", same or "none", "\n")

print("## A list parted from the paragraph before it\n")
if all(have("list-rule-off", d) for d in docs):
    rows = []
    for d in docs:
        P, L, G = lp("list-rule-off", d)
        rows.append([d.name, len(L), sum(l["nb"] for l in L)]
                    + [len(parted(s, d)) if have(s, d) else "-" for s in ["keep-off", "list-rule-off", "list-0", "list-10000", "current"]])
    rows.append(["total"] + [sum(r[i] for r in rows if r[i] != "-") for i in range(1, 8)])
    table(["document", "lists", "right after a heading", "keep-off", "-51", "0", "10000", "current"], rows)
    rows = []
    for s in ["list-0", "list-10000", "current"]:
        if not all(have(s, d) for d in docs):
            continue
        fwd, up, new, worst = 0, 0, 0, 0.0
        for d in docs:
            base = {x["id"]: x for x in parted("list-rule-off", d)}
            now = {x["id"] for x in parted(s, d)}
            P, L, G = lp(s, d)
            new += len(now - set(base))
            for l in L:
                if l["id"] in base and l["id"] not in now and l["para"] in P:
                    pg = P[l["para"]]
                    if pg > base[l["id"]]["ppage"]:
                        fwd += 1
                        g = G.get(pg - 1)
                        if g:
                            worst = max(worst, (g[1] - g[2]) / g[3])
                    else:
                        up += 1
        e = [x["e"] for d in docs for x in parted(s, d) if x["e"] is not None]
        rows.append([s, fwd, up, new, f"{worst:.1f}", f"{max(e):.1f}" if e else "none"])
    table(["setting", "lead-ins go forward with the list", "no longer parted, earlier pages shifted",
           "newly parted", "largest e on the page they leave", "largest e on parted pages"], rows)
    print("Parted at -51 (paragraph page -> list page):")
    for d in docs:
        for x in parted("list-rule-off", d):
            print(f"  {d.name} {x['typ']} {x['ppage']}->{x['page']} e={x['e'] if x['e'] is None else round(x['e'], 1)}")
            if a.context:
                pg = open(R("list-rule-off", d, ".txt"), errors="replace").read().split("\f")
                tail = [t for t in pg[x["ppage"] - 1].split("\n") if t.strip()][-4:]
                head = [t for t in pg[x["page"] - 1].split("\n") if t.strip()][:3]
                print("     before:", " / ".join(t[:70] for t in tail))
                print("     after: ", " / ".join(t[:70] for t in head))
    print()

print("## Warnings\n")
rows = []
for s in sett:
    c = collections.Counter()
    for d in docs:
        if have(s, d):
            log = open(R(s, d, ".log"), errors="replace").read()
            for m in re.findall(r"Package didactic Warning: (.*?)\n\n", log, re.S):
                t = re.sub(r"\s|\(didactic\)", "", m)  # TeX wraps the log anywhere
                c["heading" if "keepafterheading" in t or "heading" in t[:30].lower() else
                  "tie released" if "nottied" in t else "other"] += 1
    rows.append([s, sum(c.values()), c["tie released"], c["heading"], c["other"]])
table(["setting", "all", "a tie released", "headings", "other"], rows)

print("## Against current: pages whose words differ\n")
rows = []
for s in sett:
    if s == "current" or not all(have(s, d) and have("current", d) for d in docs):
        continue
    rows.append([s] + [diff("current", s, d) for d in docs])
table(["setting"] + [d.name for d in docs], rows)
print("The noprobe row checks the probe: it must not change the words on any page.")
for d in docs:
    if have("noprobe", d) and have("current", d):
        x = json.load(open(R("noprobe", d, ".json")))["pages"]
        y = json.load(open(R("current", d, ".json")))["pages"]
        if x != y:
            raise SystemExit(f"{d.name}: the probe changes the page count, {x} against {y}")
        n = diff("noprobe", "current", d)
        if n:
            raise SystemExit(f"{d.name}: the probe changes the words on {n} pages")
