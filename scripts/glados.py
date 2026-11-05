#!/usr/bin/env python3
"""Inert compatibility entrypoint after GLaDOS ownership migration."""

import sys

if __name__ == "__main__":
    if sys.argv[1:2] != ["phrase"]:
        print("GLaDOS moved to the standalone glados skill; use glados-agent.", file=sys.stderr)
        sys.exit(1)
