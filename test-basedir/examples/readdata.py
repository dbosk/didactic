import sys

with open(sys.argv[1], encoding="utf-8") as f:
    print(f.read(), end="")
