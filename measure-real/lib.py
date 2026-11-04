"""Shared by the scripts of measure-real: the configuration and the settings."""
import argparse, configparser, os, re, subprocess

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
    # The break before a list's first item, without the package's own rule.
    "list-rule-off": {"tail": NOTIE},
    "list-0": {"tail": NOTIE + "\n" + beginpar("0")},
    "list-10000": {"tail": NOTIE + "\n" + beginpar(r"\@M")},
}
PAPER = ["keep-off", "keepleadin-off", "current", "pair-1000-10000", "pair-10000-10000",
         "afterheading-1", "list-rule-off", "list-0", "list-10000"]

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
