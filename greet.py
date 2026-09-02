"""Greet the person named on the command line."""

import sys

if len(sys.argv) > 1:
    print(f"Hej, {sys.argv[1]}!")
else:
    print("Hej, okänd!")
