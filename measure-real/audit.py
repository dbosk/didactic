#!/usr/bin/env python3
"""Check that each copy really holds the document, and reads nothing else.

Two checks a page count needs, because neither failure shows in the count:
an \\input can resolve through TEXINPUTS to a file of another name elsewhere,
and reused output can name files by absolute path, which -recorder doesn't show
when minted reads them.  Prints FAIL for what makes the row wrong and NOTE for
what limits it.  Exits with 1 on any FAIL.
"""
import collections, os, re, shutil, subprocess
from lib import also, args, latex, pages_of, run

a, docs = args(__doc__, ("--sty", dict(required=True, help="the didactic.sty to use")),
               ("--also", dict(action="append", help="another file to put next to the document")))
home = os.path.expanduser("~")
dist = [run(["kpsewhich", "--var-value=" + v]).stdout.strip()
        for v in ("TEXMFDIST", "TEXMFSYSVAR", "TEXMFSYSCONFIG", "TEXMFVAR", "TEXMFCONFIG", "TEXMFLOCAL")]
dist = [d for d in dist if d] + ["/etc", "/var", run(["kpsewhich", "--var-value=SELFAUTOPARENT"]).stdout.strip()]
PACKAGE = re.compile(r"\.(sty|cls|clo|def|cfg|fd|ldf|map|tfm|vf|pfb|enc|bbx|cbx|lbx|dbx|lua|otf|ttf|ttc|afm|pfm)$"
                     r"|\.code\.tex$|/tikz|/pgf")
READS = re.compile(r"\\(input|include|subimport|import|inputminted|VerbatimInput|lstinputlisting|includegraphics)\b")
fails = 0


def say(level, doc, text):
    global fails
    fails += level == "FAIL"
    print(f"  {level}: {text}")


for d in docs:
    print(f"== {d.name} ({d.kind})")
    top = os.path.join(a.work, "audit", d.name)
    if os.path.exists(top):
        shutil.rmtree(top)
    os.makedirs(top)
    subprocess.run(["cp", "-al", os.path.join(a.work, "src", d.name) + "/.", top + "/"], check=True)
    cwd = os.path.join(top, d.dir)
    if d.out != ".":
        shutil.rmtree(os.path.join(cwd, d.out))
        shutil.copytree(os.path.join(d.src(a.work), d.out), os.path.join(cwd, d.out), symlinks=True)
    sty = os.path.join(cwd, "didactic.sty")
    if os.path.exists(sty):
        os.remove(sty)
    shutil.copy(a.sty, sty)
    also(cwd, a.also)
    latex(d, cwd, recorder=True)
    base = os.path.join(cwd, d.out, d.main)
    fls = open(base + ".fls", errors="replace").read()
    log = open(base + ".log", errors="replace").read()
    pwd = os.path.realpath(cwd)
    copy = os.path.realpath(top)
    read = set()
    for f in re.findall(r"^INPUT (.*)$", fls, re.M):
        p = os.path.normpath(f if f.startswith("/") else os.path.join(pwd, f))
        if p.startswith(copy + "/"):
            read.add(os.path.relpath(p, pwd))
        elif not any(p.startswith(x + "/") for x in dist) and not PACKAGE.search(p):
            say("FAIL", d, "reads from outside its copy (-recorder): " + p.replace(home, "~"))
    # Absolute paths in what the copy holds.
    src = d.src(a.work)
    for b, ds, fs in os.walk(src):
        ds[:] = [x for x in ds if x not in ("_minted", "figs")]
        for f in fs:
            if not f.endswith((".stdout", ".pytxmcr", ".tex")):
                continue
            for line in open(os.path.join(b, f), errors="replace"):
                if line.lstrip().startswith("%") or (d.root not in line and home not in line):
                    continue
                rel = os.path.relpath(os.path.join(b, f), src)
                if READS.search(line):
                    say("FAIL", d, f"an absolute path it would read, in {rel}: {line.strip()[:100].replace(home, '~')}")
                else:
                    say("NOTE", d, f"an absolute path in the text of {rel}, not read")
                break
    # What's read and what isn't.
    tex = sorted(x for x in read if x.endswith(".tex") and not x.startswith(d.out + "/"))
    lines = [(x, sum(1 for _ in open(os.path.join(cwd, x), errors="replace"))) for x in tex]
    print("  reads:", " ".join(f"{os.path.basename(x)}:{n}" for x, n in sorted(lines, key=lambda t: -t[1])[:9]),
          f"({len(tex)} files, {sum(n for _, n in lines)} lines)")
    unread = 0
    for x in tex:
        t = "\n".join(l for l in open(os.path.join(cwd, x), errors="replace").read().split("\n")
                      if not l.lstrip().startswith("%"))
        for m in re.finditer(r"\\(input|include)\{([^}#\\]+)\}", t):
            c = [os.path.normpath(os.path.join(os.path.dirname(x), n)) for n in (m[2], m[2] + ".tex")] + \
                [os.path.normpath(n) for n in (m[2], m[2] + ".tex")]
            if not any(n in read for n in c):
                if any(os.path.exists(os.path.join(cwd, n)) for n in c):
                    unread += 1  # present, but in a branch for another mode
                else:
                    say("FAIL", d, f"\\{m[1]}{{{m[2]}}} in {x} has no file in the copy")
        for m in re.finditer(r"\\IfFileExists\{([^}]*)\}", t):
            if "#" in m[1]:
                say("NOTE", d, f"a guarded input in {x}: {m[1]}, check that its targets exist")
            elif not os.path.exists(os.path.join(cwd, m[1])):
                say("FAIL", d, f"a guarded input in {x} has no target: {m[1]}")
    if unread:
        say("NOTE", d, f"{unread} inputs with a file in the copy weren't read: a branch for another mode?")
    for b, ds, fs in os.walk(src):
        ds[:] = [x for x in ds if x not in (d.out, "_minted", "makefiles")]
        for f in fs:
            if f.endswith(".nw"):
                p = os.path.join(b, f)
                rel = os.path.relpath(p, src)
                t = p[:-3] + ".tex"
                if rel[:-3] + ".tex" not in read:
                    say("NOTE", d, f"{rel} isn't woven into this document")
                elif os.path.getmtime(p) > os.path.getmtime(t):
                    days = (os.path.getmtime(p) - os.path.getmtime(t)) / 86400
                    say("NOTE", d, f"{rel} is {days:.1f} days newer than what's woven from it")
    # The log, and the text against the document's last build.
    u = len(set(re.findall(r"Citation '([^']*)'[^\n]*undefined", log)))
    if u:
        say("NOTE", d, f"{u} undefined citations, from reused .bbl")
    if re.search(r"run Biber", log):
        say("NOTE", d, "the log asks for a biber run")
    e = len(re.findall(r"^!", log, re.M))
    if e:
        say("FAIL", d, f"{e} LaTeX errors in the audit pass")
    w = lambda x: len(x.split())
    ours = run(["pdftotext", base + ".pdf", "-"]).stdout
    earlier = os.path.join(src, d.out, d.main + ".pdf")
    note = ""
    if os.path.exists(earlier):
        old = run(["pdftotext", earlier, "-"]).stdout
        ratio = w(ours) / max(1, w(old))
        note = f"; last build there: {pages_of(earlier)} pages, {w(old)} words, ratio {ratio:.2f}"
        if not 0.8 < ratio < 1.25:
            say("FAIL", d, f"the text is {ratio:.2f} of its last build: is the main text there?")
    print(f"  now: {pages_of(base + '.pdf')} pages, {w(ours)} words" + note)
    if not fails:
        shutil.rmtree(top)
print(f"{fails} FAIL")
raise SystemExit(1 if fails else 0)
