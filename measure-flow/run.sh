#!/bin/bash
P=$(dirname "$(readlink -f "$0")")
name=$1; ver=$2; eng=${3:-pdflatex}
d=$P/r/$name; rm -rf "$d"; mkdir -p "$d/_minted"; cd "$d" || exit 1
if [ "$ver" != no ]; then cp "$P/../v/$ver/"*.sty .; fi
python3 "$P/gen.py" t.tex "$P/cfg.json" "$name"
for i in 1 2 3 4; do
  old=$(md5sum t.aux 2>/dev/null)
  timeout 400 $eng -shell-escape -interaction=nonstopmode t >/dev/null 2>&1 </dev/null; rc=$?
  new=$(md5sum t.aux 2>/dev/null)
  [ "$old" = "$new" ] && [ $i -gt 1 ] && break
done
echo "$name passes=$i rc=$rc pages=$(pdfinfo t.pdf 2>/dev/null | awk '/Pages/{print $2}') didactic=$(grep -c '(./didactic.sty' t.log) errs=$(grep -c '^!' t.log)"
