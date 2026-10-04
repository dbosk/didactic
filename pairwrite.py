import sys

mode, text = sys.argv[1], sys.argv[2]
with open("pairfile.txt", mode) as file:
  file.write(text + "\n")
