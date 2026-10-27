#!/bin/sh
set -eu

script=$(dirname "$0")/../scripts/check-installed.sh

test "$(sh "$script" sh)" = 'sh: installed'

if output=$(sh "$script" sh __obsidian_journal_missing_command__); then
  exit 1
else
  test "$?" -eq 1
  test "$output" = "$(printf 'sh: installed\n__obsidian_journal_missing_command__: missing')"
fi

if sh "$script" > /dev/null 2>&1; then
  exit 1
else
  test "$?" -eq 2
fi
