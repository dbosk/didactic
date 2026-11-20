#!/usr/bin/env python3
"""Random documents dense with margin notes, built and checked by their outcome.

The generator and the checker come from the third review of the one-pass placement
(its gen.py and chk.py), with movers added: a paragraph that can't break, a display
after a callout, a heading's keep, a passage in the mode carry, multicol's columns
after a note at the foot, and a footnote of LaTeX's own (\\footnotesatfoot) after
ours.

Usage:
  test-fuzz.py gen SEED [backlog]  print the document of SEED (of the set backlog)
  test-fuzz.py check DIR/NAME      check a built document; PASS or the problems
  test-fuzz.py selftest            the checker's rules on made-up documents, no TeX
  test-fuzz.py run [SET...]        build and check the sets (all if none), in
                                   test-fuzz.d/; exit 1 on an unexpected outcome;
                                   $CASES, SET:SEED each, runs only those

The sets: inrun (seeds 1-40, 52 and 125, pdflatex, the marginfix found or
$MARGINFIX), tl12 (seeds 1-20, pdflatex, TeX Live's 1.2), xe and lua (seeds 1-10, xelatex and
lualatex, as inrun), stale (seeds 1-10, as inrun: a sentence added at the start,
built from the original's .aux and from clean, the same PDF), review (the review's
own documents, without the movers, where it found a defect), backlog (seeds 1-10 and 17,
as inrun, with passages in the mode carry whose long footnotes are more than a
page's margin holds).  A document is
built until its .aux settles (at most seven runs, a run limit of 300 s).

The check (each item a problem): an error in the log; a note on another page
than its callout that no warning names by its line (deferrable notes apart); a
warning whose pages aren't the labels'; a note whose label is missing; two words
that overlap; a margin or a foot out of order on a page; footnotes out of order
across pages; a note printed twice or not at all; a document that doesn't settle.

EXPECTED lists the cases that fail for a known reason, each with it; the run
fails if one of them passes (the list can't go stale) or if any other fails.
"""
import os
import random
import re
import shutil
import subprocess
import sys
import traceback

import testlog

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "test-fuzz.d")
TL12 = os.path.join(subprocess.run(["kpsewhich", "-var-value", "TEXMFDIST"],
                                   capture_output=True, text=True).stdout.strip(),
                    "tex", "latex")
SETS = {
    # and 52 and 125: a footnote that ran a line past the foot, and its line went on
    # (B1's route, found by a search of seeds 41-160; carried now)
    "inrun": [("pdflatex", "found", s) for s in list(range(1, 41)) + [52, 125]],
    "tl12": [("pdflatex", "tl12", s) for s in range(1, 21)],
    "xe": [("xelatex", "found", s) for s in range(1, 11)],
    "lua": [("lualatex", "found", s) for s in range(1, 11)],
    "stale": [("pdflatex", "found", s) for s in range(1, 11)],
    # the review's own documents (no movers) where it found B1
    "review": [("pdflatex", "tl12", 1)],
    # long footnotes carried in a row, more than a page's margin holds (review 4, S5-1)
    # and 17: a split \ltnote's rest with a stale number named as a waiting footnote
    # (review 5's last look, NL2)
    "backlog": [("pdflatex", "found", s) for s in list(range(1, 11)) + [17]],
}
# (set, seed): why it fails.  (review 1 and xe 1 were B1's, a footnote cut to run a
# line past the foot and printed over the next when its line went on; such a footnote
# is carried now.)
EXPECTED = {
    ("inrun", 52): "the mixed foot (#104): our 38 at page 3's foot with LaTeX's 41,"
                   " put back by LaTeX behind a later margin note's line and taken with"
                   " it to page 4, after 39, 40 and 42; named found from the last run",
}
TOL = 0.5  # pt: pdftotext's word boxes against TeX's widths

W = ("alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi "
     "omicron pi rho sigma tau upsilon").split()


def gen(seed, opts=(), movers=True, backlog=False):
    """A random memoir document with didactic, dense with notes; without the
    movers, the review's document of that seed; with backlog (the set backlog),
    also passages in the mode carry whose long footnotes are more than a page's
    margin holds."""
    R = random.Random(seed)
    k = 0

    def words(n):
        return " ".join(R.choice(W) for _ in range(n))

    def fn(n=None, body=None):
        nonlocal k
        k += 1
        n = n or R.choice([3, 6, 10, 18, 30, 45])
        b = body if body is not None else words(n)
        return f"\\label{{c-{k}}}\\footnote{{\\label{{n-{k}}}NOTE{k}x {b}}}"

    cls = "twoside" if "twoside" in opts or R.random() < .3 else "oneside"
    over = R.choice(["foot", "foot", "carry"])
    draft = R.random() < .1
    hyper = R.random() < .4
    out = [f"% fuzz seed {seed}: {cls}, noteoverflow={over}{',draft' if draft else ''}, "
           f"hyperref={hyper}",
           f"\\documentclass[a4paper,{cls}]{{memoir}}",
           "\\usepackage{xcolor,amsmath,amssymb,multicol}",  # amssymb before didactic, which may load unicode-math
           "\\usepackage[draft]{didactic}" if draft
           else f"\\usepackage[noteoverflow={over}]{{didactic}}",
           "\\usepackage[noamsthm,notheorems]{beamerarticle}",
           "\\usepackage{hyperref}" if hyper else "",
           "\\extrafloats{100}",
           "\\begin{document}"]
    # The review's constructs, drawn from R in its order (so that its seeds give its
    # documents); the movers and the mixed feet are drawn from a stream of their
    # own (R2) and added after a sentence's construct.
    R2 = random.Random(seed * 7919 + 1)

    def w2(n):
        return " ".join(R2.choice(W) for _ in range(n))

    for p in range(R.randint(14, 24)):
        out.append("")
        for s in range(R.randint(2, 7)):
            out.append(words(R.randint(8, 25)) + ".")
            r = R.random()
            if r < .45:
                out.append(fn())
            elif r < .50:
                k += 1
                out.append(f"\\label{{c-{k}}}\\marginpar{{\\label{{n-{k}}}NOTE{k}x MP "
                           f"{words(R.randint(5, 30))}}}")
            elif r < .55:
                k += 1
                out.append(f"\\label{{c-{k}}}\\ltnote{{\\label{{n-{k}}}NOTE{k}x LT "
                           f"{words(R.randint(10, 40))}}}")
            elif r < .60:
                out.append("\\begin{itemize}\\item " + words(8))
                out.append(fn())
                out.append("\\item " + words(10) + "\\end{itemize}")
            elif r < .64:
                k += 1
                out.append(f"\\label{{c-{k}}}\\footnotemark{{}} " + words(6))
                out.append(f"\\label{{t-{k}}}\\footnotetext{{\\label{{n-{k}}}NOTE{k}x "
                           f"{words(R.randint(5, 25))}}}")
            elif r < .68:
                out.append(words(5))
                out.append(fn())
                out.append("\\[ x^2 + y^2 = z^2 \\]")
            elif r < .72:
                out.append(f"\\section{{Heading {p}.{s}}}")
                out.append(fn())
            elif r < .76:
                pl = R.choice("tbhp")
                h = R.choice([2, 5, 9, 14]) if pl != "p" else 18
                out.append(f"\\begin{{figure}}[{pl}]\\centering\\rule{{.7\\linewidth}}"
                           f"{{{h}cm}}\\caption{{Fig}}\\end{{figure}}")
            elif r < .78:
                out.append(fn(body=words(5) + "\\begin{itemize}\\item one\\item two"
                              "\\end{itemize}" + words(5)))
            elif r < .80:
                out.append(fn(body=words(4) + " \\textcolor{red}{red words} " + words(6)))
            elif r < .81:
                out.append(fn(n=160))
            elif r < .82:
                out.append("\\enlargethispage{\\baselineskip}")
            elif r < .83:
                out.append("\\nopagebreak")
            elif r < .835:
                out.append("\\clearpage")
            elif r < .85 and hyper:
                out.append(fn(body=words(4) + " \\href{https://example.org/a/b}{link} "
                              + words(4)))
            elif r < .87:
                out.append(fn())
            m = R2.random() if movers else 1
            if m < .004:
                # a paragraph that can't break, with a footnote in its first lines
                out.append("{\\interlinepenalty=10000 " + w2(6))
                out.append(fn(n=1, body=w2(R2.choice([3, 6, 10, 18]))))
                out.append(w2(R2.randint(40, 120)) + "\\par}")
            elif m < .008:
                # a display right after a callout's line
                out.append(w2(3))
                out.append(fn(n=1, body=w2(R2.choice([3, 6, 10, 18]))))
                out.append("\\[ \\begin{matrix} a\\\\ b\\\\ c \\end{matrix} \\]")
            elif m < .013:
                # a heading whose keep may take the lines before it on
                out.append(w2(R2.randint(20, 40)))
                out.append(fn(n=1, body=w2(R2.choice([3, 6, 10, 18]))))
                out.append(f"\\subsection{{Kept {p}.{s}}}" + w2(30))
            elif m < .018:
                # a passage in the mode carry
                out.append("{\\marginnoteoverflow{carry}" + w2(4))
                out.append(fn(n=1, body=w2(R2.choice([3, 6, 10, 18]))) + "}")
            elif m < .024:
                # multicol's columns after a note that may go to the foot
                out.append(w2(4))
                out.append(fn(n=1, body=w2(R2.choice([3, 6, 10, 18]))))
                out.append("\\begin{multicols}{2}" + w2(30))
                out.append(fn(n=1, body=w2(6)))
                out.append(w2(30) + "\\end{multicols}")
            elif m < .030:
                # a footnote of LaTeX's own after ours
                out.append(w2(4))
                out.append(fn(n=1, body=w2(R2.choice([3, 6, 10, 18]))))
                out.append("{\\footnotesatfoot " + w2(4))
                out.append(fn(n=1, body=w2(6)) + "}")
            elif backlog and m < .045:
                # a passage in the mode carry with long footnotes, more than a page's
                # margin holds, so that some go on past the next page (review 4, S5-1)
                out.append("{\\marginnoteoverflow{carry}% long carry")
                for _ in range(R2.randint(4, 8)):
                    out.append(w2(3))
                    out.append(fn(n=1, body=w2(R2.randint(150, 260))))
                out.append("}")
    out.append("\\end{document}")
    return "\n".join(out) + "\n"


def check(base):
    """The problems of a built document base (base.tex, .aux, .log, .pdf): its
    files read, and judged by judge()."""
    rd = lambda ext: open(base + ext, errors="replace").read()
    bbox = subprocess.run(["pdftotext", "-bbox", base + ".pdf", "-"],
                          capture_output=True, text=True).stdout
    return judge(os.path.basename(base), rd(".tex"), rd(".aux"), rd(".log"),
                 testlog.joined(base + ".log"), bbox)


def judge(name, tex, aux, rawlog, log, bbox):
    """The problems of a document from its source (tex), its .aux, its log as
    written (rawlog) and as testlog.joined() gives it (log), and pdftotext -bbox's
    output (bbox).

    Each footnote is of one of three kinds, by its source: didactic's (a \\footnote
    or a \\footnotemark with its \\footnotetext, set in the margin or sent to the
    foot by didactic), LaTeX's own (in a \\footnotesatfoot group) or multicol's (in
    multicol's columns).  A \\footnotetext's note is compared with the label put at
    the \\footnotetext (t-K), where it is anchored, not with the mark's.  A note on
    another page than its anchor must be named by a warning whose pages match the
    labels: for didactic's, one that says it is set on another page in the run, or
    "TeX ended page P" for a note on P + 1; "found from the last run" names it only
    where its foot also holds a footnote of LaTeX's own or multicol's (the mixed
    foot, #104: INFO), since otherwise it is the record net catching what nothing
    foresaw; for multicol's, the one that says that LaTeX set it there ("where
    LaTeX puts it"); one of LaTeX's own that TeX sets on another page is LaTeX's,
    named by nothing (didactic names only multicol's, review 5): INFO, counted.  A
    note warned as not printed that is printed fails.  Footnotes keep their order
    across pages when both of a pair are didactic's, but for a footnote set before
    one still waiting with the warning that names both (INFO): the known mixed foot
    (a later line takes a foot that also holds LaTeX's own footnotes to the next
    page, named a run late; #104 is its cure) fails here, and a seed that shows it
    goes into EXPECTED with that reason.  A pair with a footnote of LaTeX's own or
    multicol's is in order or else every note of it that is off its anchor's page
    is named, LaTeX's own counting as named.  Two words that overlap fail, but for TeX's overfull line: a word of
    the text whose right edge lies past the text's right edge (the edge most lines
    of the page end at), over a word in the margin, by no more than an Overfull
    \\hbox of a paragraph in the log is wide, less TOL (0.5pt, pdftotext's boxes
    against TeX's widths), the Overfull logged after k pages were shipped (the
    log's page marks) and the overlap on page k + 1 or k + 2; TeX warns of that
    line, and didactic places no note there.  (xe seed 2 has one: "Overfull \\hbox (9.93341pt too wide) in paragraph
    at lines 154--158", into a margin note; didactic v2.17 on master gives the same
    line for that document.)  The exceptions are lines starting INFO, counted by
    kind."""
    src = tex.split("\n")
    lineof, kind = {}, {}
    for i, l in enumerate(src, 1):
        for m in re.finditer(r"\\label\{c-(\d+)\}", l):
            K = m[1]
            lineof[K] = i
            # the generator puts a footnote of LaTeX's own on the line after
            # "{\\footnotesatfoot", and multicol's on the line after "\\begin{multicols}"
            if i > 1 and "\\footnotesatfoot" in src[i - 2]:
                kind[K] = "latex"
            elif i > 1 and "\\begin{multicols}" in src[i - 2]:
                kind[K] = "multicol"
            else:
                kind[K] = "ours"
    pg = dict(re.findall(r"\\newlabel\{([cnt]-\d+)\}\{\{[^}]*\}\{([^}]*)\}", aux))
    probs = []
    errs = re.findall(r"(?m)^! .*", rawlog)
    if errs:
        probs.append(f"errors: {errs[:3]}")

    def anchor(K):
        return pg.get("t-" + K) or pg.get("c-" + K)

    # what the warnings name, by the line they name: (from page, to page or None, how)
    named = {}
    for m in re.finditer(r"Margin note called out at ([^\s:]+):(\d+)[^\n]{0,40}?on page (\d+) "
                         r"is set on (?:page (\d+)( \(found from the last run\))?|a later page)",
                         log):
        named.setdefault(int(m[2]), []).append((m[3], m[4], "last" if m[5] else "run"))
    for m in re.finditer(r"Footnote called out at ([^\s:]+):(\d+)( in multicols)? on page (\d+) "
                         r"is set at the foot of page (\d+), where (LaTeX) puts it", log):
        named.setdefault(int(m[2]), []).append((m[4], m[5], m[6]))
    # TeX ended page P before the footnote's line: the note goes with its line to P + 1
    for m in re.finditer(r"TeX ended page (\d+) before the line of the footnote called out "
                         r"at ([^\s:]+):(\d+)", log):
        named.setdefault(int(m[3]), []).append((m[1], str(int(m[1]) + 1), "moved"))
    # not printed: names nothing; a note so named that is printed is a problem below
    unprinted = {int(m[2]) for m in re.finditer(
        r"Margin note called out(?: at ([^\s:]+):(\d+))?[^\n]{0,40}?on page \d+[^\n]{0,20}? "
        r"wasn't printed", log) if m[2]}

    def lines_of(K):
        ln = lineof[K]
        return [ln, ln + 1] if pg.get("t-" + K) else [ln]

    # "Footnote called out at Y is set at the foot of page P before the one called out
    # at X, which is still waiting in the margin": by Y's line, (P, X's line)
    ahead = {}
    for m in re.finditer(r"Footnote called out at [^\s:]+:(\d+) is set at the foot of page "
                         r"(\d+) before the one called out at [^\s:]+:(\d+), which is still "
                         r"waiting in the margin", log):
        ahead.setdefault(int(m[1]), []).append((m[2], int(m[3])))
    # a page's foot that holds a footnote of LaTeX's own or multicol's: (page, its K)
    mixed = {}
    for L in lineof:
        if kind[L] in ("latex", "multicol") and pg.get("n-" + L):
            mixed.setdefault(pg["n-" + L], L)
    lastinfo = []

    def is_named(K):
        """Whether K, off its anchor's page, is named with the pages the labels have:
        in the run, or found from the last run where its foot also holds a footnote
        of LaTeX's own or multicol's (the mixed foot, #104: INFO); found from the
        last run otherwise is the record net catching something unforeseen, and
        names nothing here.  TeX ended page P names a note on P + 1."""
        a, n = anchor(K), pg.get("n-" + K)
        for ln in lines_of(K):
            for p, q, h in named.get(ln, []):
                if h == "moved":
                    if q == n:
                        return True
                elif p == a and q == n:
                    if h != "last":
                        return True
                    if n in mixed:
                        lastinfo.append((K, n, mixed[n]))
                        return True
        return False

    away, lost, latexoff = [], [], []
    for K in sorted(lineof, key=int):
        a, n = anchor(K), pg.get("n-" + K)
        if n is None:
            lost.append(K)
            continue
        if a != n and "\\ltnote" not in src[lineof[K] - 1] and not is_named(K):
            # a footnote of LaTeX's own that TeX sets on another page: LaTeX's, unnamed
            # (review 5: didactic names only multicol's)
            if kind[K] == "latex":
                latexoff.append((K, a, n))
            else:
                away.append((K, lineof[K], kind[K], a, n))
    # a warning's pages are the labels'
    for K in lineof:
        for ln in lines_of(K):
            for p, q, h in named.get(ln, []):
                if h == "moved":
                    if q != pg.get("n-" + K):
                        probs.append(f"the warning for line {ln} says TeX ended page {p}, so "
                                     f"the note is on {q}; the label {pg.get('n-' + K)}")
                elif (p, q) != (anchor(K), pg.get("n-" + K)):
                    probs.append(f"the warning for line {ln} says {p}->{q}, the labels "
                                 f"{anchor(K)}->{pg.get('n-' + K)}")
    # "Page P ends early, before the line of the margin note called out at F:L": the
    # line was taken to page P + 1, so that note's anchor is there; where the note
    # itself is, the rules above judge as for any note
    for m in re.finditer(r"Page (\d+) ends early, before the (?:line of the )?margin note "
                         r"called out at [^\s:,]+:(\d+)", log):
        Ks = [K for K in lineof if int(m[2]) in lines_of(K)]
        wrong = [(K, anchor(K)) for K in Ks if anchor(K) != str(int(m[1]) + 1)]
        if wrong or not Ks:
            probs.append(f"page {m[1]} ended early before the note of line {m[2]}, but its "
                         f"callout isn't on the next page: {wrong}")
        else:
            probs.append(f"INFO early end: page {m[1]}, before the note of line {m[2]}")
    if lost:
        probs.append(f"notes without their label (lost?): {lost}")
    printed = [K for K in lineof if pg.get("n-" + K)
               and any(ln in unprinted for ln in lines_of(K))]
    if printed:
        probs.append(f"warned as not printed, but printed: {printed}")
    if away:
        probs.append(f"away, and no warning names it with its pages: {away}")
    # order across pages
    fnk = [K for K in sorted(lineof, key=int) if "\\footnote" in src[lineof[K] - 1]
           or pg.get("t-" + K)]
    fp = [(K, int(pg["n-" + K])) for K in fnk if pg.get("n-" + K, "").isdigit()]
    bad, info = [], {}
    for i, (a, pa) in enumerate(fp):
        for b, pb in fp[i + 1:]:
            if pb >= pa:
                continue
            ka, kb = kind[a], kind[b]
            if ka == "ours" and kb == "ours":
                # b set at its foot before a, still waiting: named by the warning on b,
                # with b's page and a waiting footnote at or after a set later
                if any(p == pg.get("n-" + b) and any(
                        lineof[X] == xl or pg.get("t-" + X) and lineof[X] + 1 == xl
                        for X in lineof if int(X) >= int(a)
                        and pg.get("n-" + X, "0").isdigit() and int(pg["n-" + X]) > pb)
                       for ln in lines_of(b) for p, xl in ahead.get(ln, [])):
                    info.setdefault("ours set before ours still waiting", []).append((a, b))
                else:
                    bad.append((a, b))
            else:
                off = [K for K in (a, b) if anchor(K) != pg.get("n-" + K)]
                if all(is_named(K) or kind[K] == "latex" for K in off):
                    info.setdefault(f"{ka} after {kb}", []).append((a, b))
                else:
                    bad.append((a, b))
    if bad:
        probs.append("footnotes out of order across pages: "
                     + ", ".join(f"{a} ({kind[a]}) after {b} ({kind[b]})" for a, b in bad[:5]))
    for k, v in sorted(info.items()):
        probs.append(f"INFO {k}: {len(v)} pairs, e.g. {v[:3]}")
    if latexoff:
        probs.append(f"INFO LaTeX's own off its page: {len(latexoff)} footnotes, e.g. "
                     f"{latexoff[:3]}")
    for K, n, L in sorted(set(lastinfo), key=lambda x: int(x[0])):
        probs.append(f"INFO mixed foot: {K} named found from the last run, on page {n}, "
                     f"whose foot holds {L} ({kind[L]})")
    mg = re.search(r"didactic-margin: odd=([\d.]+) even=([\d.]+) width=([\d.]+)", log)
    if mg is None:
        probs.append("no line didactic-margin in the log: the margin isn't known")
        return name, probs
    odd, even, mw = float(mg[1]), float(mg[2]), float(mg[3])
    # each Overfull \hbox of a paragraph with the pages shipped before it in the log
    # (TeX's page marks, [1, [2, ...): its lines are on the next page or the one after
    overfull, shipped = [], 0
    for m in re.finditer(r"(?m)^Overfull \\hbox \(([\d.]+)pt too wide\) in paragraph"
                         r"|\[(\d+)(?=[\]\s{<])", rawlog):
        if m[2] is not None:
            if int(m[2]) == shipped + 1:
                shipped += 1
        else:
            overfull.append((float(m[1]), shipped))
    seen = {}
    for n, page in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", bbox, re.S), 1):
        ws = [(float(a), float(b), float(c), float(d), t) for a, b, c, d, t in
              re.findall(r'<word xMin="([-\d.]+)" yMin="([-\d.]+)" xMax="([-\d.]+)" '
                         r'yMax="([-\d.]+)">([^<]*)<', page)]
        mx = odd if n % 2 or "oneside" in src[0] else even
        foot, marg = [], []
        for w in ws:
            for t in re.findall(r"NOTE(\d+)x", w[4]):
                seen.setdefault(t, []).append(n)
                (marg if mx - 5 <= w[0] <= mx + mw else foot).append((w[1], int(t)))
        for lst, where in ((foot, "foot"), (marg, "margin")):
            ks = [t for _, t in sorted(lst)
                  if "\\ltnote" not in src[lineof.get(str(t), 1) - 1]]
            if ks != sorted(ks):
                probs.append(f"p{n} {where} order {ks}")
        pairs = [(a, b) for i, a in enumerate(ws) for b in ws[i + 1:]
                 if min(a[2], b[2]) - max(a[0], b[0]) > 1
                 and min(a[3], b[3]) - max(a[1], b[1]) > 1]
        inmarg = lambda w: mx - 5 <= w[0] <= mx + mw
        ends = {}
        for w in ws:
            if not inmarg(w):
                ends[round(w[2], 1)] = ends.get(round(w[2], 1), 0) + 1
        edge = max(ends, key=ends.get) if ends else None
        bad, over = [], {}
        for a, b in pairs:
            body, other = (a, b) if not inmarg(a) else (b, a)
            past = (body[2] - edge) * 72.27 / 72 if edge is not None else 0
            wide = [x for x, k in overfull if x >= past - TOL and k + 1 <= n <= k + 2]
            if not inmarg(body) and inmarg(other) and past > TOL and wide:
                over.setdefault((body, past, min(wide)), []).append(other[4])
            else:
                bad.append((a[4], b[4]))
        for (body, past, amount), others in over.items():
            probs.append(f"INFO TeX's overfull line: p{n} {body[4]} {past:.2f}pt past "
                         f"the text, the log's Overfull \\hbox {amount}pt, over "
                         f"{' '.join(others)} in the margin")
        if bad:
            probs.append(f"p{n} overlap {bad[:4]}")
    dup = {t: p for t, p in seen.items() if len(p) > 1}
    miss = [K for K in lineof if K not in seen]
    if dup:
        probs.append(f"a note printed more than once: {dup}")
    if miss:
        probs.append(f"a note not in the PDF: {miss}")
    return name, probs


def build(d, name, engine, mfx, runs=7, keep_aux=False):
    """Build d/name.tex until its .aux settles; True if it settled."""
    env = dict(os.environ)
    tools = os.path.join(TL12, "tools")
    path = [".", tools]
    if mfx == "tl12":
        path.insert(1, os.path.join(TL12, "marginfix") + "//")
    elif os.environ.get("MARGINFIX"):
        path.insert(1, os.path.abspath(os.environ["MARGINFIX"]) + "//")
    env["TEXINPUTS"] = ":".join(path) + ":" + os.environ.get("TEXINPUTS", "")
    aux = os.path.join(d, name + ".aux")
    if not keep_aux and os.path.exists(aux):
        os.remove(aux)
    for i in range(runs):
        old = open(aux, "rb").read() if os.path.exists(aux) else None
        try:
            subprocess.run([engine, "-interaction=nonstopmode", name + ".tex"], cwd=d,
                           env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=300)
        except subprocess.TimeoutExpired:
            return False
        new = open(aux, "rb").read() if os.path.exists(aux) else None
        log = open(os.path.join(d, name + ".log"), errors="replace").read()
        if old is not None and old == new and "Rerun to get" not in log:
            return True
    return False


def words_of(pdf):
    out = subprocess.run(["pdftotext", "-bbox", pdf, "-"], capture_output=True,
                         text=True).stdout
    return [l for l in out.split("\n") if "<meta" not in l]


def one(setname, engine, mfx, seed):
    """Build and check one case; the problems found."""
    d = os.path.join(WORK, f"{setname}-{seed}")
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(os.path.join(d, "_minted"))
    shutil.copy(os.path.join(HERE, "didactic.sty"), d)
    name = f"fz{seed}"
    open(os.path.join(d, name + ".tex"), "w").write(gen(seed, movers=setname != "review", backlog=setname == "backlog"))
    probs = []
    if not build(d, name, engine, mfx):
        probs.append("doesn't settle in seven runs")
    probs += check(os.path.join(d, name))[1]
    if setname == "stale":
        src = open(os.path.join(d, name + ".tex")).read().replace(
            "\\begin{document}\n", "\\begin{document}\nAn added sentence at the start, "
            "which moves every line after it a little.\n", 1)
        for kind in ("stale", "clean"):
            e = os.path.join(d, kind)
            os.makedirs(os.path.join(e, "_minted"))
            shutil.copy(os.path.join(HERE, "didactic.sty"), e)
            open(os.path.join(e, "st.tex"), "w").write(src)
            if kind == "stale":
                shutil.copy(os.path.join(d, name + ".aux"), os.path.join(e, "st.aux"))
            if not build(e, "st", engine, mfx, runs=8, keep_aux=kind == "stale"):
                probs.append(f"the edited document doesn't settle from {kind}")
        if words_of(os.path.join(d, "stale", "st.pdf")) != \
                words_of(os.path.join(d, "clean", "st.pdf")):
            probs.append("the edited document comes out otherwise from the old .aux "
                         "than from clean")
    return probs


MOVERS = [("unbreakable", "\\interlinepenalty=10000"), ("display", "\\begin{matrix}"),
          ("keep", "\\subsection{Kept"), ("carry", "\\marginnoteoverflow{carry}"),
          ("multicols", "\\begin{multicols}"), ("mixed foot", "\\footnotesatfoot"),
          ("long carry", "% long carry")]


def synthetic(notes, warn=(), extra=(), raw="", margin=305):
    """A small made-up document for judge(): notes are (K, kind, mark page, note
    page[, \footnotetext page]), kind ours, latex or multicol; warn are (K, how,
    from page, to page), how set (didactic's, "is set on page"), TeX or multicol
    (LaTeX's "where LaTeX puts it", with "in multicols" for multicol);
    how may also be ahead (set at the foot of page p before q, still waiting:
    q is a note's K), last ("is set on page" found from the last run), moved
    ("TeX ended page" from page, to page unused), lost ("wasn't printed") or early
    ("Page p ends early, before the line of the margin note", to page unused);
    extra are words (page, x0, y0, x1, y1, text) beside the notes' (each note's
    word spans the text, x 50 to 300, so the text's edge is at 300; the margin
    starts at x margin); raw is put in the log as written."""
    tex, line = ["% synthetic"], {}
    for K, kind, c, n, *t in notes:
        if kind == "latex":
            tex.append("{\\footnotesatfoot")
        elif kind == "multicol":
            tex.append("\\begin{multicols}{2}")
        line[K] = len(tex) + 1
        if t:
            tex += [f"\\label{{c-{K}}}\\footnotemark{{}}",
                    f"\\label{{t-{K}}}\\footnotetext{{\\label{{n-{K}}}NOTE{K}x a}}"]
        else:
            tex.append(f"\\label{{c-{K}}}\\footnote{{\\label{{n-{K}}}NOTE{K}x a}}")
    aux = "".join(f"\\newlabel{{c-{K}}}{{{{}}{{{c}}}}}\n\\newlabel{{n-{K}}}{{{{}}{{{n}}}}}\n"
                  + (f"\\newlabel{{t-{K}}}{{{{}}{{{t[0]}}}}}\n" if t else "")
                  for K, kind, c, n, *t in notes)
    log = [f"didactic-margin: odd={margin} even={margin} width=100"]
    for K, how, p, q in warn:
        if how == "set":
            log.append(f"Package didactic Warning: Margin note called out at fz.tex:{line[K]}"
                       f" on page {p} is set on page {q}: why")
        elif how == "ahead":
            log.append(f"Package didactic Warning: Footnote called out at fz.tex:{line[K]} is"
                       f" set at the foot of page {p} before the one called out at"
                       f" fz.tex:{line[q]}, which is still waiting in the margin.")
        elif how == "last":
            log.append(f"Package didactic Warning: Margin note called out at fz.tex:{line[K]}"
                       f" on page {p} is set on page {q} (found from the last run): nothing"
                       " said so in that run.")
        elif how == "moved":
            log.append(f"Package didactic Warning: TeX ended page {p} before the line of the"
                       f" footnote called out at fz.tex:{line[K]}, which had gone to its foot")
        elif how == "lost":
            log.append(f"Package didactic Warning: Margin note called out at fz.tex:{line[K]}"
                       f" on page {p} wasn't printed (found from the last run)")
        elif how == "early":
            log.append(f"Package didactic Info: Page {p} ends early, before the line of the"
                       f" margin note called out at fz.tex:{line[K]}, 12.0pt short: why")
        else:
            mc = " in multicols" if how == "multicol" else ""
            log.append(f"Package didactic Warning: Footnote called out at fz.tex:{line[K]}{mc}"
                       f" on page {p} is set at the foot of page {q}, where LaTeX puts it")
    words = [(n, 50, 600 + 10 * i, 300, 608 + 10 * i, f"NOTE{K}x")
             for i, (K, kind, c, n, *t) in enumerate(notes)] + list(extra)
    pages = max([w[0] for w in words] + [1])
    bbox = "".join("<page>" + "".join(
        f'<word xMin="{a}" yMin="{b}" xMax="{c}" yMax="{d}">{w}</word>'
        for p, a, b, c, d, w in words if p == n) + "</page>" for n in range(1, pages + 1))
    return judge("synthetic", "\n".join(tex), aux, raw, "\n".join(log), bbox)[1]


def selftest():
    """The checker's rules on small made-up documents, each rule from both sides,
    and the verdicts' rules on made-up outcomes; no TeX.  Exit 1 on a mismatch."""
    def fails(probs):
        return [p for p in probs if not p.startswith("INFO ")]

    def has(probs, text):
        return any(text in p for p in probs)

    # lines of text that end at the edge (300), and a word 11bp, 11.04pt, past it
    over = [(1, 50, 300 + 10 * i, 300, 308 + 10 * i, f"TEXT{i}") for i in range(4)] \
        + [(1, 280, 100, 311, 110, "BODY")]
    marg = [(1, 306, 101, 330, 109, "MARG")]
    cases = [
        # order across pages
        ("(ours, ours) out of order, both named, fails",
         synthetic([(1, "ours", 1, 2), (2, "ours", 1, 1)], [(1, "set", 1, 2)]),
         lambda r: has(r, "out of order across pages: 1 (ours) after 2 (ours)")),
        ("latex after ours, the late one named with its pages, is INFO",
         synthetic([(1, "latex", 1, 2), (2, "ours", 1, 1)], [(1, "TeX", 1, 2)]),
         lambda r: not fails(r) and has(r, "INFO latex after ours")),
        ("the same with the warning's pages wrong fails",
         synthetic([(1, "latex", 1, 2), (2, "ours", 1, 1)], [(1, "TeX", 1, 3)]),
         lambda r: has(r, "says 1->3")),
        ("the same unnamed is INFO, LaTeX's own off its page",
         synthetic([(1, "latex", 1, 2), (2, "ours", 1, 1)]),
         lambda r: not fails(r) and has(r, "INFO LaTeX's own off its page: 1")
         and has(r, "INFO latex after ours")),
        ("multicol's off its page unnamed fails",
         synthetic([(1, "multicol", 1, 2), (2, "ours", 1, 1)]),
         lambda r: has(r, "out of order") and has(r, "away")),
        ("multicol set a page early, named, is INFO",
         synthetic([(1, "ours", 2, 2), (2, "multicol", 2, 1)], [(2, "multicol", 2, 1)]),
         lambda r: not fails(r) and has(r, "INFO ours after multicol")),
        # off its page
        ("ours off its page, unnamed, fails",
         synthetic([(1, "ours", 1, 2)]), lambda r: has(r, "away")),
        ("ours off its page, named with its pages, passes",
         synthetic([(1, "ours", 1, 2)], [(1, "set", 1, 2)]), lambda r: not r),
        ("a \\footnotetext's note is held to its own label, not the mark's",
         synthetic([(1, "ours", 1, 2, 2)]), lambda r: not r),
        ("... and off that label's page, unnamed, fails",
         synthetic([(1, "ours", 1, 3, 2)]), lambda r: has(r, "away")),
        # a footnote set at its foot before one still waiting, warned
        ("(ours, ours) out of order, the early one warned with both places, is INFO",
         synthetic([(1, "ours", 1, 2), (2, "ours", 1, 1)], [(1, "set", 1, 2), (2, "ahead", 1, 1)]),
         lambda r: not fails(r) and has(r, "INFO ours set before ours still waiting")),
        ("... the warning's page not the early one's fails",
         synthetic([(1, "ours", 1, 2), (2, "ours", 1, 1)], [(1, "set", 1, 2), (2, "ahead", 2, 1)]),
         lambda r: has(r, "out of order across pages: 1 (ours) after 2 (ours)")),
        ("... the warning naming one not set later fails",
         synthetic([(1, "ours", 1, 2), (2, "ours", 1, 1), (3, "ours", 1, 1)],
                   [(1, "set", 1, 2), (2, "ahead", 1, 3)]),
         lambda r: has(r, "out of order across pages: 1 (ours) after 2 (ours)")),
        # the namings, by their pages
        ("ours off its page, named only found from the last run, fails",
         synthetic([(1, "ours", 1, 2)], [(1, "last", 1, 2)]), lambda r: has(r, "away")),
        ("... with a footnote of LaTeX's own at that foot, is INFO mixed foot",
         synthetic([(1, "ours", 1, 2), (2, "latex", 2, 2)], [(1, "last", 1, 2)]),
         lambda r: not fails(r) and has(r, "INFO mixed foot: 1 named found from the last "
                                           "run, on page 2, whose foot holds 2 (latex)")),
        ("... with LaTeX's own on another page's foot, fails",
         synthetic([(1, "ours", 1, 2), (2, "latex", 1, 1)], [(1, "last", 1, 2)]),
         lambda r: has(r, "away")),
        ("TeX ended page 1 names a note on page 2",
         synthetic([(1, "ours", 1, 2)], [(1, "moved", 1, None)]), lambda r: not r),
        ("... but not one on page 3",
         synthetic([(1, "ours", 1, 3)], [(1, "moved", 1, None)]),
         lambda r: has(r, "away") and has(r, "says TeX ended page 1")),
        ("a note warned as not printed that is printed fails",
         synthetic([(1, "ours", 1, 1)], [(1, "lost", 1, None)]),
         lambda r: has(r, "warned as not printed, but printed: ['1']")),
        ("... and printed on its page without the warning passes",
         synthetic([(1, "ours", 1, 1)]), lambda r: not r),
        # a page that ends early before a note's line
        ("page 1 ends early before a note's line, line and note on page 2: INFO",
         synthetic([(1, "ours", 2, 2)], [(1, "early", 1, None)]),
         lambda r: not fails(r) and has(r, "INFO early end: page 1")),
        ("... the callout still on page 1 fails, the note carried and named or not",
         synthetic([(1, "ours", 1, 2)], [(1, "early", 1, None), (1, "set", 1, 2)]),
         lambda r: has(r, "page 1 ended early before the note of line")),
        ("... the callout on page 2 and the note carried on, unnamed, fails as any note",
         synthetic([(1, "ours", 2, 3)], [(1, "early", 1, None)]),
         lambda r: has(r, "away") and not has(r, "ended early before")),
        ("... and named with its pages passes",
         synthetic([(1, "ours", 2, 3)], [(1, "early", 1, None), (1, "set", 2, 3)]),
         lambda r: not fails(r)),
        # words over words
        ("a line past the edge over a margin note, the log's Overfull as wide, is INFO",
         synthetic([(1, "ours", 1, 1)], extra=over + marg,
                   raw="Overfull \\hbox (11.0pt too wide) in paragraph at lines 1--2\n"),
         lambda r: not fails(r) and has(r, "INFO TeX's overfull line: p1 BODY 11.04pt")),
        ("... the log's Overfull narrower by less than TOL is INFO",
         synthetic([(1, "ours", 1, 1)], extra=over + marg,
                   raw="Overfull \\hbox (10.6pt too wide) in paragraph at lines 1--2\n"),
         lambda r: not fails(r)),
        ("... narrower by more than TOL fails",
         synthetic([(1, "ours", 1, 1)], extra=over + marg,
                   raw="Overfull \\hbox (10.4pt too wide) in paragraph at lines 1--2\n"),
         lambda r: has(r, "p1 overlap")),
        ("... the Overfull before page 1 is shipped (page mark [1 after it) is INFO",
         synthetic([(1, "ours", 1, 1)], extra=over + marg,
                   raw="Overfull \\hbox (11.0pt too wide) in paragraph at lines 1--2\n[1]\n"),
         lambda r: not fails(r) and has(r, "INFO TeX's overfull line")),
        ("... the Overfull only after page 1 is shipped fails",
         synthetic([(1, "ours", 1, 1)], extra=over + marg,
                   raw="[1]\nOverfull \\hbox (11.0pt too wide) in paragraph at lines 1--2\n"),
         lambda r: has(r, "p1 overlap")),
        ("... with no Overfull in the log fails",
         synthetic([(1, "ours", 1, 1)], extra=over + marg), lambda r: has(r, "p1 overlap")),
        ("two words in the margin over each other fail, an Overfull in the log or not",
         synthetic([(1, "ours", 1, 1)], extra=over + [(1, 306, 201, 330, 209, "MARG"),
                                                      (1, 310, 201, 340, 209, "MARG2")],
                   raw="Overfull \\hbox (50.0pt too wide) in paragraph at lines 1--2\n"),
         lambda r: has(r, "p1 overlap [('MARG', 'MARG2')]")),
        ("a word of the text within its edge over a margin note fails, the same",
         synthetic([(1, "ours", 1, 1)], margin=295,
                   extra=over[:4] + [(1, 260, 201, 300, 209, "INSIDE"),
                                     (1, 292, 202, 320, 208, "MARG")],
                   raw="Overfull \\hbox (50.0pt too wide) in paragraph at lines 1--2\n"),
         lambda r: has(r, "p1 overlap [('INSIDE', 'MARG')]")),
        ("two words of the text over each other fail",
         synthetic([(1, "ours", 1, 1)], extra=over + [(1, 290, 101, 311, 109, "BODY2")],
                   raw="Overfull \\hbox (11.0pt too wide) in paragraph at lines 1--2\n"),
         lambda r: has(r, "p1 overlap")),
    ]
    bad = 0
    for what, probs, ok in cases:
        good = ok(probs)
        bad += not good
        print(f"didactic fuzz selftest: {'PASS' if good else 'FAIL'} {what}"
              + ("" if good else f": {probs}"))

    def boom():
        raise ValueError("boom")
    verdicts = [
        ("a listed case that passes fails the run", outcome("why", lambda: []), 1),
        ("a listed case that fails doesn't", outcome("why", lambda: ["p1 overlap"]), 0),
        ("an unlisted case that fails fails the run", outcome(None, lambda: ["x"]), 1),
        ("an unlisted case with INFO only passes", outcome(None, lambda: ["INFO k: x"]), 0),
        ("an exception in a case is its failure", outcome(None, boom), 1),
    ]
    for what, (verdict, failed, probs, infos), want in verdicts:
        good = failed == want and (what[:5] != "an ex" or has(probs, "boom"))
        bad += not good
        print(f"didactic fuzz selftest: {'PASS' if good else 'FAIL'} {what}"
              + ("" if good else f": {verdict} {probs}"))
    return 1 if bad else 0


def movers_line(setname):
    """How many of a set's documents have each mover."""
    cases = SETS[setname]
    docs = [gen(seed, movers=setname != "review", backlog=setname == "backlog") for _, _, seed in cases]
    counts = ", ".join(f"{name} {sum(1 for d in docs if mark in d)}" for name, mark in MOVERS)
    return f"didactic fuzz test: {setname}: documents with each mover: {counts} (of {len(docs)})"


def outcome(why, case):
    """The verdict on one case: (verdict, whether it fails the run, problems,
    INFO lines).  why is its reason in EXPECTED or None; case() builds and checks
    it, and an exception in it is its failure."""
    try:
        probs = case()
    except Exception:
        probs = ["the test itself failed: " + traceback.format_exc().strip().split("\n")[-1]]
    infos = [p for p in probs if p.startswith("INFO ")]
    probs = [p for p in probs if not p.startswith("INFO ")]
    if probs and why:
        return f"FAIL as expected ({why})", 0, probs, infos
    if probs:
        return "FAIL", 1, probs, infos
    if why:
        return f"PASS, expected to fail ({why}): take it off the list", 1, probs, infos
    return "PASS", 0, probs, infos


def run(sets):
    os.makedirs(WORK, exist_ok=True)
    status = 0
    kinds, ndocs = {}, 0
    # $CASES: only these documents, SET:SEED each (make mutants' group fuzz)
    only = os.environ.get("CASES", "").split()
    for setname in sets:
        if only and not any(c.split(":")[0] == setname for c in only):
            continue
        print(movers_line(setname), flush=True)
        for engine, mfx, seed in SETS[setname]:
            if only and f"{setname}:{seed}" not in only:
                continue
            verdict, failed, probs, infos = outcome(
                EXPECTED.get((setname, seed)), lambda: one(setname, engine, mfx, seed))
            status |= failed
            ndocs += bool(infos)
            for p in infos:
                k = p[5:].split(":")[0]
                kinds[k] = kinds.get(k, 0) + 1
            print(f"didactic fuzz test: {setname} seed {seed} {verdict}", flush=True)
            for p in probs:
                print(f"  {p}", flush=True)
            for p in infos:
                print(f"  {p}", flush=True)
    print(f"didactic fuzz test: INFO in {ndocs} documents: "
          + (", ".join(f"{k} {n}" for k, n in sorted(kinds.items())) or "none"), flush=True)
    return status


if __name__ == "__main__":
    if sys.argv[1:2] == ["gen"]:
        sys.stdout.write(gen(int(sys.argv[2]), backlog=sys.argv[3:4] == ["backlog"]))
    elif sys.argv[1:2] == ["check"]:
        try:
            name, probs = check(sys.argv[2])
        except Exception:
            probs = ["the check itself failed: "
                     + traceback.format_exc().strip().split("\n")[-1]]
        print("\n".join(probs) if probs else "PASS")
        sys.exit(1 if [p for p in probs if not p.startswith("INFO ")] else 0)
    elif sys.argv[1:2] == ["selftest"]:
        sys.exit(selftest())
    elif sys.argv[1:2] == ["run"]:
        sys.exit(run(sys.argv[2:] or list(SETS)))
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
