# measure-flow: page breaks in generated literate programs

The rows on generated documents in the appendix on measurement
(`\label{app:pb-measure}` in the package documentation) come from here. It needs no
documents of yours, only `pdflatex`, `pdfinfo`, Python 3, `noweb.sty`, `minted` and
`lipsum`.

Each configuration is one LaTeX document of 12 generated ones (seeds), each of 60
pairs of a code chunk and text, in `memoir` with `article` and `oneside`. The lengths
of the chunks and the share of a lone `@` follow the maintainer's `.nw` files
(`gen.py`). There are no margin notes, floats or displays. The chunks are set by noweb,
or by `minted` as noweb's `tominted` filter weaves them, with filler code. An output
routine prints, for each page, the penalty it broke at and its height and natural
height, which the two scripts below read from the log.

## Running it

From the repository's root, after `make didactic.sty`:

    mkdir -p v/current && cp didactic.sty v/current/
    mkdir -p v/kept && sed 's/\\let\\nwdocspar\\relax/\\relax/' didactic.sty > v/kept/didactic.sty
    cd measure-flow && python3 cfgmake.py
    ./run.sh none no; ./run.sh bc no; ./run.sh mintp no           # plain
    ./run.sh n current; ./run.sh nn current; ./run.sh m current   # the package
    python3 stats.py none bc mintp n nn m
    python3 pages.py none bc mintp n nn m                         # pages per document

- `cfgmake.py` writes `cfg.json` beside it: the preamble of each configuration.
- `run.sh NAME VER [ENGINE]` builds configuration `NAME` in `r/NAME/`, with
  `v/VER/didactic.sty` from the repository's root, or with no package when `VER` is
  `no`, and `ENGINE` (default `pdflatex`). It runs at most four passes, until the
  `.aux` doesn't change, and prints the passes, the exit code, the pages, whether
  `didactic.sty` was loaded, and the number of errors.
- `stats.py NAME...` gives the empty space at the foot of each page, `e` in lines of
  12pt, and the penalties the pages broke at. It leaves out each document's last page,
  which ends by itself and so says nothing of a break: it prints `pages=198` where the
  appendix says 210.
- `pages.py NAME...` counts every page of the 12 documents, which is the appendix's
  Pages, and the pages that broke at a club or widow penalty: 1000 or 1100 a first line
  alone, 1001 or 1101 a last line alone (with a widow penalty of 1001), 2001 or 2101
  both.

Warnings are counted in the log: `grep -c 'Package didactic Warning' r/NAME/t.log`.
Runs of different names don't share files, so they can run side by side.
`queries/pen.py` is the same comparison of penalties with no package, also from the
root: `python3 queries/pen.py EMPTYDIR 300`.

## The configurations

All are in `cfgmake.py`, and each is used in the appendix, in the subsections on
generated literate programs (the first table and the one of `keepmaxgap` and
`\nwdocspar` apart) and on the pair of penalties:

| Name | Chunks | What | Tables |
|---|---|---|---|
| `none` | noweb | plain, no option | programs |
| `bc` | noweb | plain, `breakcode` | programs |
| `nn` | noweb | the package, no option | programs |
| `n` | noweb | the package, `breakcode` | programs; pair; nwdocspar |
| `nG` | noweb | `keepmaxgap=0` | programs; nwdocspar |
| `nK` | noweb | `v/kept`: the limit on, noweb's break kept | nwdocspar |
| `nD` | noweb | `keepmaxgap=0`, the break dropped | nwdocspar |
| `nA`, `nB`, `nW` | noweb | club/widow 1000/10000, 10000/10000, 1000/1001 | pair |
| `mintp` | minted | plain | programs |
| `m` | minted | the package | programs; pair; nwdocspar |
| `mG0` | minted | `keepmaxgap=0` | programs; nwdocspar |
| `mLead0` | minted | `keepleadin=false` | programs |
| `mL0` | minted | `keeplines=0` | programs |
| `mK` | minted | `v/kept`: the limit on, the break kept | nwdocspar |
| `mD` | minted | `keepmaxgap=0`, the break dropped | nwdocspar |
| `mA`, `mB`, `mW` | minted | the three pairs | pair |

`nK` and `mK` take `kept` as `VER`, the others `current` (or `no` for the plain ones).
`nW` and `mW` break as 1000/1000 does, and tell its lone last lines from its first ones.
Earlier rounds had more configurations, which no table uses; they are in the history,
in `cfgmake.py` up to ebec67a.
