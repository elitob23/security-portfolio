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
# Example output: Glacier-Tunnel48%

import os
import secrets  # secrets is safer than random for passwords
import subprocess
import sys

MIN_LENGTH = 15
MAX_LENGTH = 16

# words.txt sits next to this script, so build the path from the script location.
# That way it still works no matter which folder you run the script from.
SCRIPT_FOLDER = os.path.dirname(os.path.abspath(__file__))
WORDS_FILE = os.path.join(SCRIPT_FOLDER, "words.txt")

symbols = "!@#$%&*?"


def load_words():
    """Read words.txt and sort the words into groups by how long they are."""
    words_by_length = {}
    with open(WORDS_FILE, encoding="utf-8") as words_file:
        for line in words_file:
            word = line.strip()
            if word.isalpha():
                # Start a new group the first time we see this length
                if len(word) not in words_by_length:
                    words_by_length[len(word)] = []
                words_by_length[len(word)].append(word)
    return words_by_length


def make_password(words_by_length):
    """Build one password of 15 or 16 characters."""
    # The password looks like Word-Word12!
    # That is 1 dash + 2 digits + 1 symbol = 4 characters that are not words,
    # so the two words together need to fill the rest.
    total_length = secrets.choice([MIN_LENGTH, MAX_LENGTH])
    words_length = total_length - 4

    # Pick a length for the first word, then the second word gets what is left.
    # Only keep the options where both lengths actually exist in the word list.
    first_lengths = []
    for length in words_by_length:
        if (words_length - length) in words_by_length:
            first_lengths.append(length)

    first_length = secrets.choice(first_lengths)
    second_length = words_length - first_length

    first_word = secrets.choice(words_by_length[first_length])
    second_word = secrets.choice(words_by_length[second_length])

    number = secrets.randbelow(90) + 10  # a 2 digit number, 10 to 99
    symbol = secrets.choice(symbols)

    return first_word + "-" + second_word + str(number) + symbol


def copy_to_clipboard(text):
    """Copy text to the clipboard. Returns True if it worked."""
    if sys.platform == "win32":
        commands = [["clip"]]
    elif sys.platform == "darwin":
        commands = [["pbcopy"]]
    else:
        commands = [["wl-copy"], ["xclip", "-selection", "clipboard"]]

    for command in commands:
        try:
            # clip on Windows expects the text in the system's own encoding
            subprocess.run(command, input=text.encode(), check=True)
            return True
        except (OSError, subprocess.CalledProcessError):
            # That clipboard tool is missing or failed, so try the next one
            continue
    return False


# Load the words once, before generating anything
try:
    words_by_length = load_words()
except FileNotFoundError:
    print("Could not find words.txt. It needs to sit in the same folder as this script.")
    sys.exit(1)

# Ask how many passwords to make
how_many = input("How many passwords do you need? ")

if how_many.isdigit() and int(how_many) > 0:
    password = ""
    for i in range(int(how_many)):
        password = make_password(words_by_length)
        print(password)

    # Only the last password can sit in the clipboard, so say which one it is
    if copy_to_clipboard(password):
        if int(how_many) == 1:
            print("\nCopied to clipboard.")
        else:
            print("\nCopied the last one to the clipboard.")
    else:
        print("\nCould not reach the clipboard, so copy it by hand.")
else:
    print("Please enter a number greater than 0.")
