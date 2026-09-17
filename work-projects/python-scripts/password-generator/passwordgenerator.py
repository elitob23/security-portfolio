"""
Name:         Word-Based Password Generator
Purpose:      Generate readable 15-16 character passwords for new user accounts
Inputs:       words.txt (same folder), and how many passwords to make
Outputs:      Passwords printed to the console, last one copied to the clipboard
Requirements: Python 3.10+, standard library only (no third-party packages)
Usage:        python passwordgenerator.py
Status:       Draft
"""

# Strings two words together so the password is easy to read out and type.
# Every password is 15 or 16 characters and is copied to the clipboard.
# Example output: Glacier~Tunnel48%  or  48%Glacier~Tunnel

import os
import secrets  # secrets is safer than random for passwords
import subprocess
import sys

MIN_LENGTH = 15
MAX_LENGTH = 16

symbols = "!@#$%&*?"

# The character that goes between the two words. One of these is picked
# at random each time so every password does not look the same.
separators = "-._~/+="

# words.txt sits next to this script, so build the path from the script location.
# That way it still works no matter which folder you run the script from.
script_folder = os.path.dirname(os.path.abspath(__file__))
words_file = os.path.join(script_folder, "words.txt")


def load_words():
    """Read words.txt into a list, one word per line."""
    words = []
    with open(words_file, encoding="utf-8") as open_file:
        for line in open_file:
            word = line.strip()
            if word:  # skip any blank lines
                words.append(word)
    return words


def make_password(words):
    """Build one password of 15 or 16 characters."""
    number = secrets.randbelow(90) + 10  # a 2 digit number, 10 to 99
    symbol = secrets.choice(symbols)
    separator = secrets.choice(separators)

    # The number and symbol travel together as one block, for example "62$"
    extras = str(number) + symbol

    # That block goes on the front or the back, decided at random
    extras_go_first = secrets.choice([True, False])

    # Pick two words. If they make the password too long or too short,
    # throw them away and pick two more.
    while True:
        first_word = secrets.choice(words)
        second_word = secrets.choice(words)
        middle = first_word + separator + second_word

        if extras_go_first:
            password = extras + middle
        else:
            password = middle + extras

        if MIN_LENGTH <= len(password) <= MAX_LENGTH:
            return password


def copy_to_clipboard(text):
    """Copy text to the clipboard. Returns True if it worked."""
    if sys.platform == "win32":
        command = ["clip"]  # built into Windows
    else:
        command = ["xclip", "-selection", "clipboard"]  # Linux, needs installing

    try:
        subprocess.run(command, input=text.encode(), check=True)
        return True
    except Exception:
        # The clipboard tool is missing or did not work
        return False


# Stop early if the word list is not where we expect it
if not os.path.exists(words_file):
    print("Could not find words.txt. It needs to sit in the same folder as this script.")
    sys.exit(1)

words = load_words()

# Ask how many passwords to make
how_many = input("How many passwords do you need? ")

if how_many.isdigit() and int(how_many) > 0:
    count = int(how_many)
    password = ""

    for i in range(count):
        password = make_password(words)
        print(password)

    # Only the last password can sit in the clipboard, so say which one it is
    if copy_to_clipboard(password):
        if count == 1:
            print("\nCopied to clipboard.")
        else:
            print("\nCopied the last one to the clipboard.")
    else:
        print("\nCould not reach the clipboard, so copy it by hand.")
else:
    print("Please enter a number greater than 0.")
