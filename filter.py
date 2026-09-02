"""Read all of the input and print it in upper case."""

import sys

for line in sys.stdin.read().splitlines():
    print(line.upper())
