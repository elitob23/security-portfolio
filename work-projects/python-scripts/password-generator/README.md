<img src="banner.svg" alt="password-generator" width="100%" />

# password-generator

A small Python script that builds readable 15-16 character passwords for new user accounts, then copies the result to the clipboard. Two dictionary words, a number, and a symbol: strong enough to hand out, short enough to fit password field limits, and easy to read aloud over the phone.

**Author:** Elias Tobin

[← Back to python-scripts](../README.md) · [← Back to portfolio home](../../../README.md)

## Contents

- [Purpose](#purpose)
- [How It Works](#how-it-works)
- [Usage](#usage)
- [Requirements](#requirements)
- [Files](#files)
- [Password Strength](#password-strength)
- [Notes](#notes)
- [Related Projects](#related-projects)

## Purpose

Onboarding a new user means handing them a first password. Typing keyboard mash like `xK7#qp2Lm!vZ9` over the phone wastes time and invites typos, and picking passwords by hand produces predictable ones.

This script exists to:

- Produce first-login passwords that meet a 15-character minimum without going over common field limits
- Keep them readable, so they can be dictated, typed, and confirmed quickly
- Take the choice away from a human, so there is no `Winter2025!` pattern across accounts
- Drop the password straight onto the clipboard, ready to paste into the account creation form

## How It Works

Every password follows the same shape:

```
Marlin~Hefted33%          35*Lilies=Groovy
└──┬─┘│└──┬──┘└┬┘         └┬┘ └──┬─┘│└──┬─┘
   │  │   │    └── block   │     │  │   └── second word
   │  │   └── second word  │     │  └── separator
   │  └── separator        │     └── first word
   └── first word          └── block
```

Two parts move from password to password:

- **The separator** between the words is picked at random from `- . _ ~ / + =`
- **The block** of 2-digit number and symbol goes on the front or the back, decided by a coin flip

The script builds one by trial and error:

1. Picks a 2-digit number and a symbol, so the password satisfies complexity rules that require both, then decides whether that block goes on the front or the back.
2. Picks a separator, then picks two random words and joins them with it.
3. Measures the result. If it isn't 15 or 16 characters, throws both words away and picks two more.

About a quarter of word pairs land in range, so it usually succeeds within a few tries. Generating 5,000 passwords takes a tenth of a second.

All random choices use Python's `secrets` module, not `random`. `secrets` is backed by the operating system's cryptographic random source; `random` is a predictable pseudo-random generator and is not suitable for anything that protects an account.

## Usage

```bash
python passwordgenerator.py
```

```
How many passwords do you need? 3
Names=Sneaked22%
35*Lilies=Groovy
Foam.Confines51@

Copied the last one to the clipboard.
```

Ask for one password at a time when the clipboard matters. Only one value can sit in the clipboard, so on a batch the script copies the last password and says so.

Run it from any folder. The script locates `words.txt` relative to its own path, not the working directory.

## Requirements

**Python 3.10+, standard library only.** No `pip install` step.

Clipboard support per platform:

| Platform | Clipboard tool | Included with OS? |
|---|---|---|
| Windows | `clip` | ✅ Yes, works out of the box |
| Linux | `xclip` | ❌ `sudo apt install xclip` |

macOS is not supported. Adding it would mean one more branch in `copy_to_clipboard()` using `pbcopy`.

If no clipboard tool is available, the script still prints the passwords and notes that the copy did not happen. Generation never depends on the clipboard.

## Files

| File | Purpose |
|---|---|
| [passwordgenerator.py](passwordgenerator.py) | The script |
| [words.txt](words.txt) | 34,912 words, 4-8 letters, plain a-z, proper nouns removed |
| [requirements.txt](requirements.txt) | Dependency notes (no packages required) |
| [banner.svg](banner.svg) | README banner |

`words.txt` has to stay in the same folder as the script. To change the vocabulary, edit the file: one word per line, letters only. Word pairs that cannot hit 15-16 characters are discarded and retried, so mixing in words of any length is fine. Keep some in the 4-8 letter range though: if no pair in the file can reach 15-16 characters, the retry loop has nothing to find and will spin.

## Password Strength

These passwords carry roughly **39 bits of entropy**. Read that as: no realistic chance of being guessed against a login prompt that rate-limits or locks out, but not built to survive offline cracking if a password hash is stolen.

That is a deliberate trade. Readability at 15-16 characters costs entropy — a 4-word version of this script reached ~61 bits, but produced passwords around 30 characters. For temporary credentials that users replace at first login, 39 bits is the right side of the trade.

The random separator and the front-or-back placement add about 4 bits between them. Worth having, but they are a small contribution next to the word choice — their real value is that passwords handed out on the same day do not look like they came off a production line.

**Use these for first-login passwords that get changed.** For credentials that persist, especially service accounts, generate longer random strings and store them in a password manager.

## Notes

- Nothing is written to disk and nothing is logged. Passwords exist in the console output and the clipboard only.
- Clear the clipboard after pasting. Clipboard contents persist and are readable by other applications on the machine.
- `words.txt` is generated from a standard system dictionary. It contains no environment-specific data.
- Proper nouns are filtered out, so passwords read as ordinary words rather than surnames and place names.

## Related Projects

- [Domain-Wide Password Policy Overhaul](../../password-policy): the 15-character minimum this script is built to satisfy
- [JIT Access Model](../../jit-access-model): just-in-time access, the other half of account provisioning
- [python-scripts](../README.md): the rest of the Python tooling in this repo
