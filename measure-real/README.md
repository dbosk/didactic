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

A document that has moved on since the last measurement isn't the same document.
For a comparison between versions of the package, keep `results/` and the `src/`
copies, or a snapshot to point `root` at.

## The steps

- `prepare.py` copies each document, with what its last build read from outside
  its directory, weaves it if the configuration says so, and points absolute
  paths in reused output at the copy.
- `audit.py` runs each copy once with `-recorder` and reports FAIL or NOTE. **Fix
  every FAIL before measuring**, and read the NOTEs: they limit the rows.
- `build.py` builds every document under every setting of `lib.py`, until its
  `.aux` settles. It saves the numbers under the tag, and only then deletes the
  build. A build with a LaTeX error, a quota or full-disk line in its log, a log
  without its output line, or an `.aux` that doesn't settle is marked as no result,
  and its build stays. A rerun must fail on those, not produce a short count.
- `analyse.py` prints the tables, and stops at a row that isn't a result or if
  the probe changes a page count.

`probe.py` holds the code added to the copy of the package.

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
- Builds killed by a timeout whose LaTeX children kept running and wrote into the
  next build of that directory.

## Limits

- Generated files are as last built, the same for every setting.
- Lone lines and gaps cover pages through the main output routine, not float pages.
- The probe can move lines between pages without changing the page count. Take
  page counts and warnings from `noprobe`, and read each list on such a document
  in its unprobed text as well.
- A list is measured against the last paragraph before it, whatever lies between.
  Read the `--context` output.

## The generated literate programs

The rows on generated documents in that appendix are from `measure-flow/`, which
needs no documents of yours:

    mkdir -p v/current && cp didactic.sty v/current/
    cd measure-flow && python3 cfgmake.py
    ./run.sh none no; ./run.sh bc no; ./run.sh mintp no           # plain
    ./run.sh n current; ./run.sh nn current; ./run.sh m current   # the package
    python3 stats.py none bc mintp n nn m

The names are in `cfgmake.py`: `n` is breakcode, `nn` no option, `m` minted chunks.
