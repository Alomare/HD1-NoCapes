"""Checks a changelog section for the release workflow (.github/workflows/release.yml).

    python tools/release_notes.py check section.md

section.md holds one version's section of CHANGELOG.md. A changelog is a list, one change per line
("- New: ..."), with nothing else in it, and follows the rules for public text: no em or en dashes, and none
of the words in WORDS.
"""

import re
import sys

WORDS = re.compile(r"\b(it'?s|i|me|my|we|our|us|you|your)\b", re.I)  # the possessive, and first and second person


def lines(text):
    return [s.strip() for s in text.replace("\r", "").split("\n") if s.strip()]


def check(text):
    problems = []
    entries = lines(text)
    if not entries:
        problems.append("the changelog is empty")
    for s in entries:
        if not s.startswith("- ") or len(s) < 3:
            problems.append(f"not a list entry (one change per line, starting with \"- \"): {s}")
            continue
        body = re.sub(r"`[^`]*`", "", s[2:])  # code, such as an option id, isn't prose
        hit = WORDS.search(body)
        if hit:
            problems.append(f"\"{hit.group(0)}\" in: {s}")
        if "—" in s or "–" in s:
            problems.append(f"a dash in: {s}")
    return problems


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "check":
        sys.exit(__doc__)
    with open(sys.argv[2], encoding="utf-8") as f:
        problems = check(f.read())
    for p in problems:
        print(p)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
