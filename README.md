# didactic

This package provides macros and environments useful for writing teaching 
material. It provides more semantic environments on top of the standard 
`definition`, `theorem`, and friends: for instance, `exercise`, `activity` and 
`question`. These are suitably colour coded when used with Beamer. They occur 
as "normal" text in handouts produced by `beamerarticle` (same style as 
`definition` usually has).

It also provides macros for typesetting code listings and output side by side.

For a bilingual source, it provides the environments `en` and `sv` and the 
command `\ensv`, with which one source yields an English and a Swedish edition. 
The script `didactic-sync.py` keeps the two languages of each pair in step.

Finally, it modifies the appearance of `beamer` (Berlin based theme) and 
`memoir` (Tufte style layout), if loaded. It's designed to be used with 
`beamer` to produce slides and `beamerarticle` with `memoir` to produce notes, 
and handouts from the same source.

## Installation

To use the package, you only need to install `didactic.sty` in a place where 
your LaTeX distribution can find it. For a local installation, you can put it
in the same directory as your document, or in `~/texmf/tex/latex/didactic/`.

Actually, for the latter, you can simply do the following:

```bash
mkdir -p ~/texmf/tex/latex
cd ~/texmf/tex/latex
git clone https://github.com/dbosk/didactic.git
cd didactic
make all
```

That will build `didactic.sty`, `didactic-sync.py` and `didactic.pdf`; `make
tests` runs the tests (see below). The documentation is located in
`didactic.pdf`. To build only the package, run `make didactic.sty`.

## Requirements

For the package:

- A recent LaTeX (the hooks need a format from 2021 or later; an older one gets
  a warning).
- `marginfix`. TeX Live's 1.2 is enough for the notes as the documentation
  describes them, with these differences, which the test targets ending in
  `-tl12` check: every line with a margin note may end a page, so a line that
  would move to the next page with its note stays on its page, with the note
  (one the margin can't hold then runs past its foot, with a warning); a note
  taller than the margin is lost, with marginfix's error "lost some margin
  notes", and didactic names it a run later; and there are no deferrable notes (`notepriority`, `\ltnote` giving
  way to the others) and no split of a note taller than the margin. Those come
  with the `integration` branch of
  [dbosk/marginfix](https://github.com/dbosk/marginfix), until upstream has
  them. didactic checks the names it uses in marginfix, not a version: if one
  it needs is missing, the notes are carried, as marginfix does alone, and a
  warning names what is missing.

  Install marginfix together with didactic. With the fork's `integration`
  branch as it was before this version, a margin note taller than the margin
  is lost with marginfix's error "lost some margin notes" (didactic names the
  note a run later), and a note held for its line stands a few points above
  it, as in v2.16.1; the other rows of `test-noteplace` pass, and the other
  note suites were not run against it.
- `minted` 3 (with its `latexminted`) and `pythontex`, and LaTeX run with
  `-shell-escape`.
- `comment`, for the bilingual blocks (in TeX Live), unless the option
  `nobilingual` is given.
- For `didactic-sync.py`: Python 3.10 or later, and `git` for the diffs and the
  branch check. To build it, as `make all` does, `notangle` from noweb (without
  it `make all` stops with "notangle: not found"); `black` tidies the tangled
  script if it is there, and is left out if not.

To build the documentation and run the tests, also:

- `pdflatex` (the Makefile's default engine), `xelatex` and `lualatex` (the
  tests about those engines name them: `test-noteoverflow-xe` and
  `test-noteoverflow-lua`, jobs in the note suites, `test-footwide`, the biburl
  tests); `latex` for docstrip; `makeindex` and `biber`.  The whole set runs on
  another engine with `PDFLATEX=xelatex make tests`, the engine in the
  environment: the jobs that name theirs keep it (on make's command line,
  `PDFLATEX=` would override them too).
- `pythontex` on the command line, with Python 3.
- A `noweb` whose `noweb.sty` has the option `[minted]` and whose `noweave` has
  the filter `tominted`: the `integration` branch of
  [dbosk/noweb](https://github.com/dbosk/noweb). The sweep and the noweb tests
  need it; a few other tests (`test-keep`, `test-keep-leadin`) skip their noweb
  cases without `noweb.sty`.
- `pdftotext` and `pdfinfo` (poppler), and `awk`, `sed`, `cmp`, Python 3.
- For the sync script: `notangle` and `noweave` from the noweb above, `pytest`
  and `git`; `black` is optional (it only tidies the tangled script).
- The LaTeX packages the tests load: amsmath, amssymb, amsthm, babel,
  beamer (for `beamerarticle`), beramono, biblatex, cleveref, csquotes, enumitem,
  fancyvrb, float, fontenc, graphicx, helvet, hyperref, import, lipsum, longtable,
  mathpazo, memoir, multicol, physics, refcount, tabularx, tikz, xcolor; all in
  TeX Live.
- A `latexminted` that runs, and the `minted.sty` of its release (see below).

The tests are run with TeX Live 2025 and, in `TEXMFHOME`, these on top of it:

- marginfix from the `integration` branch above, and the noweb above;
- minted 3.8.0 (2026/03/03), with fvextra 1.14.0 and latex2pydata 0.7.0
  (2026/02/25), which minted 3.8.0 requires; TeX Live 2025 ships minted 3.7.0,
  fvextra 1.13.2 and latex2pydata 0.6.0. They are needed because of
  `latexminted`: TeX Live 2025's own (0.6.0) fails under Python 3.14
  (`TypeError: ArgParser.__init__() got an unexpected keyword argument
  'color'`), so the tests use latexminted 0.7.1 from PyPI (installed with
  pipx), and it refuses a `minted.sty` older than 3.8.0 ("minted Python
  executable requires minted.sty >= 3.8.0"). Without them, `didactic.pdf` and
  ten tests (`test-run`, `test-pair`, `test-pair-slides`, `test-keep`,
  `test-keep-tall`, `test-frametitle-boxes`, `test-keep-leadin`,
  `test-keep-leadin-off`, `test-keep-overfull`, `test-keep-once`) fail on
  that error. Whether TeX Live's latexminted and minted 3.7.0 suffice under
  Python 3.13 or older has not been tried.

beamer and PythonTeX come from TeX Live 2025 (beamer 3.76, PythonTeX 0.18): a
`make -k all` from a `git archive` with only marginfix and noweb in
`TEXMFHOME`, when `all` still ran the tests, failed only on the minted error
above (the sweep variants and the other tests passed), and rebuilding the eleven
failed targets with the three minted packages added, and TeX Live's beamer and
PythonTeX, built them all (2026-11-08; the rest was not rerun with them).

Run `make` without `-j` in one directory: the documents share `_minted/` and
the example files, and parallel builds there gave minted and TeX errors that
sequential builds of the same targets didn't.

## Testing

Run LaTeX non-interactively, or an error stops the build at its prompt:

```bash
make tests LATEXFLAGS="-shell-escape -interaction=nonstopmode"
```

- `make all` builds the package, `didactic-sync.py` and the documentation,
  nothing else.
- `make tests` runs every test: the `test-*.tex` documents, each with the
  checks the Makefile states (`pdfinfo` page counts, `pdftotext` greps,
  PASS/FAIL lines), `make check`, the sweep, and the rows of where margin notes
  go (`test-noteplace`, `test-notefoot`, `test-noteoverflow-foot`,
  `test-footreuse-spread`, `test-footwide`; `test-noteplace-tl12` and
  `test-notefoot-tl12` again with TeX Live's marginfix 1.2), `test-testlog`,
  of `testlog.py`, which the checks read the logs with, and the bilingual
  checks below. A test fails `make tests`; `make -k tests` runs them all and
  lists what failed. About two hours on one job, a third of it the documents
  and the sweep.
- `MARGINFIX=<directory>` runs the tests against the `marginfix.sty` in that
  directory, put first on `TEXINPUTS` (TeX Live's:
  `MARGINFIX=$(kpsewhich -var-value TEXMFDIST)/tex/latex/marginfix`); unset,
  the one found. The `-tl12` targets use TeX Live's 1.2 whatever `MARGINFIX` is.
- `make test-sync` runs the tests of `didactic-sync.py` (pytest, with real git
  repositories in temporary directories), and `make check-bilingual` builds the
  bilingual test documents in both editions, as notes and as slides, and reads
  them with `test-bilingual.sh`. Both are part of `make tests`.
- `make check` runs `test-check.py`, which holds the documents named in the
  Makefile's `CHECKED_TESTS` to what their headers say, from the words and
  their positions in the PDF and from the log.
- `make test-keep-sweep` builds `test-keep-sweep.py`'s documents: page breaks
  around headings, lists and listings, room by room, against plain LaTeX with
  the same fonts and margins, in several variants (see its docstring). About 6
  minutes, part of `make tests`.
- `make mutants` runs `test-mutants.py`: deliberate breaks of `didactic.dtx`,
  listed in `test-mutants.txt`, each of which some test must catch, or a
  survivor recorded with its reason. It isn't part of `make tests`: the whole
  batch takes hours; see the header of `test-mutants.txt` for the groups and
  their times, and `make mutants MUTANTS="label ..."` runs some. Each mutant is
  built in a copy of the tracked files, up to about 100 MB at a time per job,
  under `$TMPDIR`; `python3 test-mutants.py --dir DIR --jobs N label ...` puts
  the copies elsewhere and runs N at a time.

The measurements behind the documentation's decisions on page breaks have their
own rigs, not run by `make`: `measure-real/` (real documents, which aren't in
the repository; see its README), with its own checks, `test_probe.py` (the
probe moves no line) and `test_rig.py` (the rig leaves its copy of a document
alone), and
`measure-flow/` (generated documents), and the scripts in `queries/`.

What isn't tested, as far as we know:

- The keep rules under KOMA-Script's classes, and under `report` and `book`
  beyond `test-keep-chapter-book`; the tests use `memoir` and `article`.
- The rules room by room under XeLaTeX or LuaLaTeX: the sweep runs under
  pdflatex only (for its fonts), as the other keep tests do by default;
  `PDFLATEX=xelatex make tests` runs them under xelatex.
- `keeplines` and `keepends` on real documents: `measure-real` has the settings
  `keeplines-0` and `keepends-3` (and `keepafterheading-3`) for it, which the
  default run leaves out; no figures from them are in the documentation yet.
- Two-sided layouts, but for a few documents (`test-footcite-twoside`,
  `test-sidecap`, `test-keep-flush`, `test-margin-log`).
- Real documents other than `memoir` ones, in the measurements.
- What the documentation lists as what the warnings can't see.


## Maintainer

The package was authored by Daniel Bosk <daniel+ctan@bosk.se>, who is also the 
maintainer.

## License

This package is licensed under the LPPL 1.3c or later.
