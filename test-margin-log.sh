#!/bin/sh
# test-margin-log.sh <name>: does the didactic-margin line in <name>.log give
# the x of the words NOTEODD and NOTEEVEN in <name>.pdf, within 0.1bp?
name=$1
line=$(grep '^didactic-margin:' "$name.log") || { echo "no didactic-margin line"; exit 1; }
odd=$(echo "$line" | sed -E 's/.*odd=([-0-9.]+).*/\1/')
even=$(echo "$line" | sed -E 's/.*even=([-0-9.]+).*/\1/')
x() { pdftotext -bbox "$name.pdf" - | sed -nE "s/.*xMin=\"([-0-9.]+)\".*>$1<.*/\1/p"; }
xodd=$(x NOTEODD)
xeven=$(x NOTEEVEN)
[ -n "$xodd" ] && [ -n "$xeven" ] || { echo "notes not found in the PDF"; exit 1; }
echo "$name: log odd=$odd even=$even, printed odd=$xodd even=$xeven"
awk -v a="$odd" -v b="$xodd" -v c="$even" -v d="$xeven" \
  'function abs(v) { return v < 0 ? -v : v }
   BEGIN { exit !(abs(a - b) < 0.1 && abs(c - d) < 0.1) }'
