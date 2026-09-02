"""Like ask.py, but with a slow import before the question (test only)."""

import time

time.sleep(1)
antal_personer = int(input("Antal personer: "))
print(3 * antal_personer / 4, "ägg")
