# Obsidian Journal skill

Install `pre-commit` and `luacheck` in your development environment, then enable both Git hook stages:

```sh
pre-commit install
pre-commit run --all-files
```

The configuration installs both hook stages. File checks run at `pre-commit`; Commitlint runs at `commit-msg`. All file checks exclude `templates/`. Checks also reject malformed YAML/JSON/TOML, merge markers, case-conflicting paths, private keys, and newly added files larger than 500 KB, and remove trailing whitespace while preserving Markdown line breaks.

Prettier, Markdownlint, and Commitlint run from versioned `pre-commit` environments. Luacheck uses the executable on `PATH`. Commit messages are validated with `@commitlint/config-conventional`, for example `feat(journal): add daily entries` or `fix: preserve existing notes`.

Prettier writes formatting changes to JSON, Markdown, YAML, TOML, Lua, and shell scripts using the indentation and line endings from `.editorconfig`. When a hook modifies files, review and stage them again before retrying the commit. Formatting on save must be enabled separately in your editor. The hook installs pinned TOML, Lua, and shell plugins in its isolated environment. Markdown preserves prose line breaks and leaves embedded code examples unchanged. Luacheck also checks Lua without formatting it.

Python formatting remains unsupported: the official Prettier Python plugin is deprecated and archived. The Lua plugin is experimental; review its output before applying it to existing scripts. Neovim uses Conform to format supported files before saving. JSON uses native Prettier support; plugins are loaded only for their matching file types. Editor integrations must have the corresponding plugins from `.prettierrc.yaml` available when formatting Lua, shell, or TOML.
