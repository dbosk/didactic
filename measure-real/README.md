# measure-real: page counts and page breaks on real documents

This is how the numbers in the appendix on measurement were made
(`\label{app:pb-measure}` in the package documentation). It measures one
`didactic.sty`, as it is and with small changes, on documents you have.

The documents aren't in the repository. A configuration file outside it says
where they are; see `measure-real.conf.example`. The documents' own directories
are only read.

## What you need

`pdflatex` (and any other engine the documents use), `pdfinfo`, `pdftotext`,
`rsync`, Python 3, and for documents that need it `noweave` and `biber`. Each
document must have been built once where it is, because its PythonTeX, biber
and minted output is reused.

## From an empty directory

    git clone <this repository> didactic && cd didactic
    make didactic.sty
    cp measure-real/measure-real.conf.example ~/measure-real.conf   # and fill it in
    cd measure-real
    W=~/measure-work                                                # about 200 MB a document
    python3 prepare.py --conf ~/measure-real.conf --work $W
    python3 audit.py   --conf ~/measure-real.conf --work $W --sty ../didactic.sty
    python3 build.py   --conf ~/measure-real.conf --work $W --sty ../didactic.sty --jobs 6
    python3 analyse.py --conf ~/measure-real.conf --work $W

To compare commits, build each under `--tag COMMIT` with its `didactic.sty`, and
pass the same `--tag` to `analyse.py`. Never run two builds on one work directory
and tag at once, and don't kill `build.py` with `timeout`: its LaTeX children
outlive it, and collide with the next build.

Add `--doc NAME` to any of them for one document, and `--setting NAME` to
`build.py` for one setting. On a loaded machine a document takes minutes per
setting. `analyse.py --context` prints the text around each parted list, for
reading whether the paragraph before it really leads into it.

**Keep a snapshot.** A snapshot keeps numbers comparable. A rerun from sources that
have moved mixes document changes with package changes, and the audit shows that
only as another word count. So after the first `prepare.py`, keep `src/` outside any
temporary directory, and give each document a `root` pointing at its copy, such as
`root = /path/to/snapshot/src/notes-1`. A document's last build at source may also
be cleaned, and then `prepare.py` refuses it.

For build time, `timing.py --sty old=PATH --sty new=PATH --doc NAME --generated 3000`
times passes in turn with two versions. Run nothing else of yours meanwhile.

## The steps

- `prepare.py` copies each document, with what its last build read from outside
  its directory, weaves it if the configuration says so, and points absolute
  paths in reused output at the copy.
- `audit.py` runs each copy once with `-recorder` and reports FAIL or NOTE. **Fix
  every FAIL before measuring**, and read the NOTEs: they limit the rows.
- `build.py` builds every document under the default settings (`noprobe`,
  `pair-1000-1001` and the list `PAPER` in `lib.py`), or those given with
  `--setting`, until its `.aux` settles, at most six passes. It saves the numbers
  under the tag, and only then deletes the build. A build with a LaTeX error, a quota
  or full-disk line in its log, a log without its output line, or an `.aux` that
  hasn't settled after the sixth pass is marked as no result, and its build stays.
  A rerun must fail on those, not produce a short count.
- `analyse.py` prints the tables, and stops at a row that isn't a result or if
  the probe changes the words on a page.

A setting is an entry of `SETTINGS` in `lib.py`, a small change to the copy of
`didactic.sty`: `defaults` sets an option's default, by rewriting the line
`\@didactic@OPTION=N` of the package (it stops if that line isn't there exactly once),
`replace` swaps other text found exactly once, `tail` adds code before `\endinput`,
`leadin` turns `keepleadin` off and `probe` the probe. For example
`"keepends-3": {"defaults": {"keepends": 3}}`. Add it to `PAPER` to have it in the
default run; `keeplines-0`, `keepends-3` and `keepafterheading-3`, for the reopen
conditions of the decisions, aren't, so give them with `--setting`.

`probe.py` holds the code added to the copy of the package.
`test_probe.py --sty ../didactic.sty` checks that a page output inside a small font
gets the same unit of a line as the others, and that the probe moves no line.
`test_rig.py --sty ../didactic.sty` runs a small document with output "." through
`prepare.py`, `audit.py` and `build.py`, two settings at a time, and checks that every
setting gives a result and that no file of the prepared copy changes.

## What went wrong before, which these checks are for

- An `\input{contents.tex}` with no woven file found a test fixture of that name
  through `TEXINPUTS`. The page count looked fine for a shorter document.
- Reused PythonTeX output named files by absolute path, read through `minted`, so
  `-recorder` didn't list them. The build broke when they were cleaned at source.
- A probe that wrote into empty paragraphs (`\noindent\par`, as noweb has) made
  lines of them and added pages. Compare `noprobe` with `current`.
- `biber` with a wrong path emptied the `.bbl`, which shows only as fewer pages.
- Builds deleted before their numbers were read, and a quota reached on the
  scratch disk while `df` still showed free space.
- The probe took a line as `\normalbaselineskip` when the page was output, which is
  9.5pt rather than 12pt inside a listing's small font, so gaps looked a quarter larger
  on such pages. `analyse.py` now stops if the unit varies.
- The probe took the last space of a paragraph away with `\unskip`, to see whether
  the paragraph was empty. A paragraph of nothing but two spaces, which noweb leaves
  for an empty chunk of text, is an empty line, and without its last space TeX
  dropped it. Lines moved on 78 pages of one literate program, with the same page
  count. The probe now puts the space back, and `analyse.py` stops if `noprobe` and
  `current` differ in words.
- Builds killed by a timeout whose LaTeX children kept running and wrote into the
  next build of that directory.
- With output ".", the default, `build.py` left the document's own directory hard-linked
  to the prepared copy, so LaTeX wrote its `.aux`, `.log` and `.pdf` into the copy and
  into every other setting's build at once: a truncated PDF, or an `.aux` that never
  settled. What LaTeX writes is now a real copy in `build.py`, `audit.py` and
  `timing.py` alike; `test_rig.py` checks it.
- `prepare.py` ran one LaTeX pass before biber with whatever `didactic.sty` was
  installed, and kept the `.aux` it wrote. Every build starts from that `.aux`, and one
  set of lecture notes settles in two states, with a table on one page or the next, so
  two rounds of the same package differed on 50 pages. Now only the new `.bbl` is kept,
  and the rest of the output is put back as the document's last build left it.

## Limits

- Generated files are as last built, the same for every setting.
- Lone lines and gaps cover pages through the main output routine, not float pages.
- The probe is checked to move no line on these documents and in `test_probe.py`,
  not in general. Page counts and warnings are still taken from `noprobe`.
- A list is measured against the last paragraph before it, whatever lies between.
  Read the `--context` output.

## The generated literate programs

The rows on generated documents in that appendix are from `measure-flow/`, which needs
no documents of yours; `measure-flow/README.md` says how to run it.
