#!/bin/sh

if [ "$#" -eq 0 ]; then
  printf 'Usage: %s command [command ...]\n' "$0" >&2
  exit 2
fi

missing=0
for app; do
  if command -v "$app" > /dev/null 2>&1; then
    printf '%s: installed\n' "$app"
  else
    printf '%s: missing\n' "$app"
    missing=1
  fi
done

exit "$missing"
