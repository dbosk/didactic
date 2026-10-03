"""Greets the user, the second version."""


class Person:
    """A person with a name."""

    def __init__(self, name):
        self.name = name

    def greet(self):
        """Returns a greeting."""
        return "Hej " + self.name


def main():
    print(Person("Ada").greet())


if __name__ == "__main__":
    main()
