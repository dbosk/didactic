"""Greets the user, the first version."""

phonebook = {
    "ada": {"name": "Ada", "phone": "0701"},
    "bob": {"name": "Bob", "phone": "0702"},
}


def greet(name):
    """Returns a greeting for name."""
    return "Hej " + name


def main():
    name = input("Vad heter du? ")
    print(greet(name))


main()
