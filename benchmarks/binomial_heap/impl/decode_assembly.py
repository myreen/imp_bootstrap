#!/usr/bin/env python3

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode an IMPL assembly bytestring")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    text = args.input.read_text()
    prefix = '     = "'
    suffix = '"\n     : bytestring\n'

    if not text.startswith(prefix) or not text.endswith(suffix):
        raise SystemExit("unexpected Rocq bytestring output")

    assembly = text[len(prefix) : -len(suffix)]
    if "\\" in assembly or '"' in assembly:
        raise SystemExit("escaped assembly output is unsupported")

    args.output.write_text(assembly)


if __name__ == "__main__":
    main()
