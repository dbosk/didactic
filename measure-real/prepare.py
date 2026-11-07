#!/usr/bin/env python3
"""Copy each document to the work directory, read-only at its source.

The copy keeps the document's path below the root, so that relative inputs
outside its directory resolve, and takes those from the .fls of its last build.
The last build's generated files come along: PythonTeX, biber and minted output
is reused, the same for every setting.  Nothing runs at the source.
"""
import os, re, shutil, subprocess
from lib import args, latex, run

a, docs = args(__doc__)
EXCL = [".git", "node_modules", ".venv", "venv", "worktrees", ".claude", "*.mp4", "didactic/"]
missing = 0
for d in docs:
    src, dst = os.path.join(d.root, d.dir), d.src(a.work)
    if not os.path.exists(os.path.join(src, d.out, d.main + ".log")):
        print(f"{d.name}: no last build at its source, so nothing to reuse: build it there first")
        missing += 1
        continue
    if os.path.exists(dst):
        shutil.rmtree(os.path.join(a.work, "src", d.name))
    os.makedirs(dst)
    r = subprocess.run(["rsync", "-aL", "--max-size=40m"] + ["--exclude=" + e for e in EXCL]
                       + [src + "/", dst + "/"], capture_output=True, errors="replace")
    if r.returncode not in (0, 24):
        raise SystemExit(f"{d.name}: the copy failed, is the disk full? {r.stderr[-300:]}")
    n = 0
    fls = os.path.join(src, d.out, d.main + ".fls")
    if os.path.exists(fls):
        for f in set(re.findall(r"^INPUT (\.\.[^\n]*)$", open(fls, errors="replace").read(), re.M)):
            s, t = os.path.normpath(os.path.join(src, f)), os.path.normpath(os.path.join(dst, f))
            if os.path.isfile(s):
                os.makedirs(os.path.dirname(t), exist_ok=True)
                shutil.copy(s, t)
                n += 1
    # Reused output can name files by absolute path, which -recorder doesn't
    # show when minted reads them: point it at the copy, or the build reads the
    # source, and fails when that has been cleaned.
    prefix, fixed = src.rstrip("/") + "/", 0
    for base, _, files in os.walk(dst):
        for f in files:
            if f.endswith((".stdout", ".pytxmcr")):
                p = os.path.join(base, f)
                t = open(p, errors="replace").read()
                if prefix in t:
                    tmp = p + ".new"
                    open(tmp, "w", errors="replace").write(t.replace(prefix, ""))
                    os.replace(tmp, p)
                    fixed += 1
    # A document whose woven source isn't kept, or isn't current in its last build.
    if d.weave:
        r = subprocess.run(d.weave, shell=True, cwd=dst, capture_output=True, errors="replace")
        if r.returncode:
            raise SystemExit(f"{d.name}: the weave failed: {r.stderr[:300]}")
    # biber needs a .bcf, so one LaTeX pass runs first.  It loads whatever
    # didactic.sty is installed and rewrites the .aux, which every build starts
    # from, and a document can settle in more than one state: so afterwards
    # everything but the new .bbl is put back as the last build left it.
    if d.biber:
        out = os.path.join(dst, d.out)
        saved = os.path.join(a.work, "src", d.name + ".before-biber")
        shutil.rmtree(saved, ignore_errors=True)
        shutil.copytree(out, saved, symlinks=True)
        latex(d, dst)
        r = run(["biber", "--quiet", "--output-directory=" + d.out, d.main], cwd=dst)
        bbl = os.path.join(out, d.main + ".bbl")
        if r.returncode or not os.path.getsize(bbl):
            raise SystemExit(f"{d.name}: biber failed or left an empty .bbl: {r.stdout[-300:]}")
        new = os.path.join(saved, d.main + ".bbl")
        shutil.copy(bbl, new)
        shutil.rmtree(out)
        os.rename(saved, out)
    print(f"{d.name}: copied, {n} files from outside its directory, {fixed} outputs repointed"
          + (", woven" if d.weave else "") + (", biber" if d.biber else ""))
raise SystemExit(1 if missing else 0)
