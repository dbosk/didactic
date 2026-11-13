# didactic

A LaTeX package for teaching material: semantic blocks, code side by side,
margin notes, and page breaks around headings, lists and listings. The README
says what it needs and how to run the tests; this file is for working on it.

## Source and build

- The source is `didactic.dtx` (literate, docstrip); `didactic.sty` and
  `didactic.pdf` are generated: never edit `didactic.sty` by hand. The
  appendices `appendix.tex`, `appendix-measure.tex` and `appendix-hitlist.tex`
  are input by the documentation.
- Run LaTeX non-interactively, keeping `-shell-escape`, or an error stops at
  the prompt:
  `make didactic.pdf LATEXFLAGS="-shell-escape -interaction=nonstopmode"`.
- `_minted/` must exist and may be empty; otherwise minted can find another
  tree's cache.
- Requires marginfix 1.6, the `integration` branch of dbosk/marginfix (TeX
  Live ships 1.2), and for the documentation and tests a noweb with `[minted]`
  and `tominted` (dbosk/noweb, `integration`), and minted 3.8.0 with fvextra
  1.14.0 and latex2pydata 0.7.0 to match latexminted 0.7.1 (TeX Live 2025's
  latexminted fails under Python 3.14). beamer and PythonTeX from TeX Live
  suffice. See the README.
- Don't run `make -j` in one directory: the documents share `_minted/`.

## Tests

- `make all` builds `didactic.sty` and `didactic.pdf` only. `make tests
  LATEXFLAGS=...` runs every test, `make check` and the note suites among them;
  about an hour and a half on one job. `MARGINFIX=<dir>` chooses the marginfix.
  The Makefile's default engine is xelatex; tests that need pdflatex or lualatex
  name it.
- A test fails `make`, by the Makefile's checks or `test-check.py`; a PDF that
  merely builds checks nothing. New checks go into `tests`.
- After a change to how notes are set, run the whole `make -k tests`, not only
  the note suites.
- `test-keep-parted.tex`: lead-ins and what they lead into, parted only with a
  warning. `test-keep-sweep.py`: page breaks room by room against plain LaTeX.
- `make mutants` (`test-mutants.py`, `test-mutants.txt`): deliberate breaks
  that a test must catch, or a survivor with its reason. Hours for the whole
  batch; groups and times are in the header of `test-mutants.txt`. Run single
  ones with `make mutants MUTANTS="label"`, and re-record an outcome when a
  change moves it.
- Red first: a new check must fail on the code before the fix.

## Decisions and measurements

- The page-break defaults are decisions, in the documentation's table
  `tab:pb-decisions` (section "Why pages break where they do"), with the
  literature in `appendix.tex` and the measurements in `appendix-measure.tex`.
  They are settled unless what the table's "Reopens" names turns up; don't
  re-evaluate them otherwise.
- Layout is correct or warns: a case that can't be guaranteed gives a warning
  naming the place, never silence; the docs list what the warnings can't see.
- `measure-real/` measures real documents, with its own checks
  `test_probe.py` and `test_rig.py` (see its README); its configuration, with
  the documents' paths, is private and stays outside the repository. Never put the
  names of those documents, or of the people or courses in them, into the
  repository. `measure-flow/` and `queries/` are the generated-text rigs and
  the literature searches' records.

## Git

- Commits are signed. `master` changes only by pull request.
