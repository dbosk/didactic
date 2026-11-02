# didactic

This package provides macros and environments useful for writing teaching 
material. It provides more semantic environments on top of the standard 
`definition`, `theorem`, and friends: for instance, `exercise`, `activity` and 
`question`. These are suitably colour coded when used with Beamer. They occur 
as "normal" text in handouts produced by `beamerarticle` (same style as 
`definition` usually has).

It also provides macros for typesetting code listings and output side by side.

For a bilingual source, it provides the environments `en` and `sv` and the 
command `\tr`, with which one source yields an English and a Swedish edition. 
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

That will build `didactic.sty`, `didactic-sync.py` and `didactic.pdf`. The 
documentation is located in `didactic.pdf`.


## Maintainer

The package was authored by Daniel Bosk <daniel+ctan@bosk.se>, who is also the 
maintainer.

## License

This package is licensed under the LPPL 1.3c or later.
