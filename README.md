# Obsidian Journal skill

Install `pre-commit` and `luacheck` in your development environment, then enable both Git hook stages:

```sh
pre-commit install --hook-type pre-commit --hook-type commit-msg
pre-commit run --all-files
```

Prettier, Markdownlint, and Commitlint run from versioned `pre-commit` environments. Luacheck uses the executable on `PATH`. Commit messages follow Conventional Commits, for example `chore: add skill tooling`.
