"""Shared by the scripts of measure-real: the configuration and the settings."""
import argparse, configparser, os, re, shutil, subprocess

# The settings are small changes to a copy of the package's didactic.sty, in
# one of two ways: `defaults` rewrites a line that sets a default, and fails if
# the line isn't there exactly once, and `tail` is code added before \endinput.
# Options can't do this: the documents load the package themselves.
PAIR = r"\AtBeginDocument{\clubpenalty=%d \csname @clubpenalty\endcsname=%d \widowpenalty=%d\relax}"
NOTIE = r"\AtBeginDocument{\let\@didactic@keep@listtie\relax}"
def beginpar(value):
    return "".join(r"\AddToHook{env/%s/begin}{\@beginparpenalty=%s\relax}" % (e, value) + "\n"
                   for e in ("itemize", "enumerate", "description"))


OFF = {"keeplines": 0, "keepends": 1, "keepafterheading": 0, "keepmaxgap": 0}
SETTINGS = {
    # What the package does.  The reference for every comparison.
    "current": {},
    # The same without the probe: a probe must not change the words.
    "noprobe": {"probe": False},
    # Which pair of club and widow penalties.
    "pair-1000-1001": {"tail": PAIR % (1000, 1000, 1001)},  # tells a club from a widow
    "pair-1000-10000": {"tail": PAIR % (1000, 1000, 10000)},
    "pair-10000-10000": {"tail": PAIR % (10000, 10000, 10000)},
    # What the keep options cost.
    "keepleadin-off": {"leadin": False},
    "keep-off": {"defaults": OFF, "leadin": False},
    "afterheading-1": {"defaults": {"keepafterheading": 1}},
    # The estimate before a heading asks for two lines, not one, as before the package's
    # rule for a list under a heading: what that rule changed.
    "estimate-2": {"replace": [(r"<\dimexpr#1+\@didactic@keep@L\relax", r"<\dimexpr#1+2\@didactic@keep@L\relax")]},
    # The break before a list's first item, without the package's own rule.
    "list-rule-off": {"tail": NOTIE},
    "list-rule-off-noprobe": {"tail": NOTIE, "probe": False},  # read the parted lists in its text
    "list-0": {"tail": NOTIE + "\n" + beginpar("0")},
    "list-10000": {"tail": NOTIE + "\n" + beginpar(r"\@M")},
    # Margin notes that don't fit carried to the next page, as before noteoverflow, against
    # the default break, which ends the page before the line that calls one out.
    "noteoverflow-carry": {"replace": [(r"{\renewcommand\@didactic@noteoverflow{break}}",
                                        r"{\renewcommand\@didactic@noteoverflow{carry}}")]},
}
PAPER = ["keep-off", "keepleadin-off", "current", "pair-1000-10000", "pair-10000-10000",
         "afterheading-1", "estimate-2", "list-rule-off", "list-0", "list-10000", "noteoverflow-carry"]

# What shows in the log when a build isn't a result: a full disk or a quota.
BAD = re.compile(r"quota exceeded|No space left|I can't write on file|Disk quota", re.I)


class Doc:
    def __init__(self, name, sec, root):
        self.name, self.kind = name, sec.get("kind", name)
        self.dir, self.main = sec["dir"], sec["main"]
        self.out = sec.get("output", ".")
        self.engine = sec.get("engine", "pdflatex")
        self.weave = sec.get("weave", "")
        self.biber = sec.getboolean("biber", False)
        self.root = os.path.expanduser(sec.get("root", root))

    def src(self, work):
        return os.path.join(work, "src", self.name, self.dir)

    def built(self, work, setting):
        return os.path.join(work, "build", setting, self.name, self.dir)

    def result(self, work, setting, ext):
        d = os.path.join(work, setting)
        os.makedirs(d, exist_ok=True)
        return os.path.join(d, self.name + ext)


def args(description, *extra):
    p = argparse.ArgumentParser(description=description)
    p.add_argument("--conf", required=True, help="the configuration file")
    p.add_argument("--work", required=True, help="a directory for copies and results")
    p.add_argument("--doc", action="append", help="only this document (repeatable)")
    p.add_argument("--tag", default="results", help="the subdirectory of the results, such as a commit")
    for a, k in extra:
        p.add_argument(a, **k)
    a = p.parse_args()
    c = configparser.ConfigParser(interpolation=None)
    if not c.read(a.conf):
        raise SystemExit("can't read " + a.conf)
    root = os.path.expanduser(c["rig"]["root"])
    docs = [Doc(n, c[n], root) for n in c.sections() if n != "rig"]
    if a.doc:
        unknown = set(a.doc) - {d.name for d in docs}
        if unknown:
            raise SystemExit("not in the configuration: " + ", ".join(sorted(unknown)))
        docs = [d for d in docs if d.name in a.doc]
    return a, docs


def workcopy(work, doc, top):
    """Copy a document's prepared source to top, to run LaTeX in; return its directory.

    Hard links save space: one copy of the sources for all settings.  But what LaTeX
    writes must be a file of this build's own, or it writes through the link into the
    prepared source and into every other build of the document at once.  So the
    output directory is a real copy, and with output "." that is the document's own
    directory: every file in it, and below it, becomes a real copy, and only files
    elsewhere, such as inputs above it, stay linked.
    """
    subprocess.run(["cp", "-al", os.path.join(work, "src", doc.name) + "/.", top + "/"], check=True)
    cwd = os.path.join(top, doc.dir)
    if doc.out != ".":
        out = os.path.join(cwd, doc.out)
        shutil.rmtree(out)
        shutil.copytree(os.path.join(doc.src(work), doc.out), out, symlinks=True)
        return cwd
    for base, _, files in os.walk(cwd):
        for f in files:
            p = os.path.join(base, f)
            if not os.path.islink(p) and os.stat(p).st_nlink > 1:
                tmp = p + ".copy~"
                shutil.copy2(p, tmp)
                os.replace(tmp, p)
    return cwd


def run(cmd, cwd=None, timeout=900, **kw):
    return subprocess.run(cmd, cwd=cwd, timeout=timeout, stdin=subprocess.DEVNULL,
                          capture_output=True, errors="replace", **kw)


def latex(doc, cwd, recorder=False, timeout=900):
    cmd = [doc.engine, "-shell-escape", "-interaction=nonstopmode"]
    if recorder:
        cmd.append("-recorder")
    if doc.out != ".":
        cmd.append("-output-directory=" + doc.out)
    return run(cmd + [doc.main + ".tex"], cwd=cwd, timeout=timeout)


def pages_of(pdf):
    m = re.search(r"Pages:\s+(\d+)", run(["pdfinfo", pdf]).stdout)
    return int(m[1]) if m else None
