# didactic

This package provides macros and environments useful for writing teaching 
material. It provides more semantic environments on top of the standard 
`definition`, `theorem`, and friends: for instance, `exercise`, `activity` and 
`question`. These are suitably colour coded when used with Beamer. They occur 
as "normal" text in handouts produced by `beamerarticle` (same style as 
`definition` usually has).

It also provides macros for typesetting code listings and output side by side.

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

That will build both `didactic.sty` and `didactic.pdf`, and run the tests (see
below). The documentation is located in `didactic.pdf`. To build only the
package, run `make didactic.sty`.

## Requirements

For the package:

- A recent LaTeX (the hooks need a format from 2021 or later; an older one gets
  a warning).
- `marginfix` 1.6 or later, for `\marginnoteoverflow` and the margin fixes the
  notes rely on. TeX Live 2025 ships 1.2; 1.6 is on the `integration` branch of
  [dbosk/marginfix](https://github.com/dbosk/marginfix) until upstream has it.
  With an older one the package works, and says what it can't do.
- `minted` 3 (with its `latexminted`) and `pythontex`, and LaTeX run with
  `-shell-escape`.

To build the documentation and run the tests, also:

- `xelatex` (the Makefile's default engine), `pdflatex` (the tests that need it
  name it) and `lualatex` (`test-noteoverflow-lua`); `latex` for docstrip;
  `makeindex` and `biber`.
- `pythontex` on the command line, with Python 3.
- A `noweb` whose `noweb.sty` has the option `[minted]` and whose `noweave` has
  the filter `tominted`: the `integration` branch of
  [dbosk/noweb](https://github.com/dbosk/noweb). The sweep and the noweb tests
  need it; a few other tests (`test-keep`, `test-keep-leadin`) skip their noweb
  cases without `noweb.sty`.
- `pdftotext` and `pdfinfo` (poppler), and `awk`, `sed`, `cmp`, Python 3.
- The LaTeX packages the tests load: amsmath, amssymb, amsthm, babel,
  beamer (for `beamerarticle`), beramono, biblatex, cleveref, csquotes, enumitem,
  fancyvrb, float, fontenc, graphicx, helvet, hyperref, import, lipsum, longtable,
  mathpazo, memoir, multicol, refcount, tabularx, tikz, xcolor; all in TeX Live.
- A `latexminted` that runs, and the `minted.sty` of its release (see below).

The tests are run with TeX Live 2025 and, in `TEXMFHOME`, these on top of it:

- marginfix 1.6 and the noweb above;
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
`TEXMFHOME` failed only on the minted error above (the sweep variants and the
other tests passed), and rebuilding the eleven failed targets with the three
minted packages added, and TeX Live's beamer and PythonTeX, built them all
(2026-11-08; the rest of `make all` was not rerun with them).

Run `make` without `-j` in one directory: the documents share `_minted/` and
the example files, and parallel builds there gave minted and TeX errors that
sequential builds of the same targets didn't.

## Testing

Run LaTeX non-interactively, or an error stops the build at its prompt:

```bash
make all LATEXFLAGS="-shell-escape -interaction=nonstopmode"
```

- `make all` builds the package and its documentation, and runs every test:
  the `test-*.tex` documents, each with the checks the Makefile states
  (`pdfinfo` page counts, `pdftotext` greps, PASS/FAIL lines), `make check`,
  and the sweep. About 17 to 20 minutes on one job.
- `make check` runs `test-check.py`, which holds the documents named in the
  Makefile's `CHECKED_TESTS` to what their headers say, from the words and
  their positions in the PDF and from the log.
- `make test-keep-sweep` builds `test-keep-sweep.py`'s documents: page breaks
  around headings, lists and listings, room by room, against plain LaTeX with
  the same fonts and margins, in several variants (see its docstring). About 6
  minutes, part of `make all`.
- `make mutants` runs `test-mutants.py`: deliberate breaks of `didactic.dtx`,
  listed in `test-mutants.txt`, each of which some test must catch, or a
  survivor recorded with its reason. It isn't part of `make all`: the whole
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
  pdflatex only (for its fonts); the other keep tests run under xelatex.
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
