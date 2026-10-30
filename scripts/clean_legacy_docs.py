#!/usr/bin/env python3
"""List tracked legacy documentation assets; --apply removes only these files."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SUFFIXES = {'.ansi', '.txt', '.html'}


def candidates():
    tracked = subprocess.check_output(['git', 'ls-files', '-z', '--', 'docs/assets/'], cwd=ROOT).decode().split('\0')
    return sorted(path for path in tracked if path and Path(path).suffix in SUFFIXES and (ROOT / path).is_file())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Delete the listed documentation assets')
    args = parser.parse_args()
    files = candidates()
    for path in files:
        print(path)
        if args.apply:
            (ROOT / path).unlink()
    print(f'{len(files)} legacy documentation assets {"removed" if args.apply else "listed; use --apply to remove"}')


if __name__ == '__main__':
    main()
