# Obsidian Journal

An agent skill for recording work sessions in an Obsidian vault, with templates
for daily entries and weekly, monthly, and historical summaries.

The project is under development. This repository currently provides the skill
outline, journal templates, a configuration installer, a journal workflow, a
configuration schema, and development tooling.

## Repository layout

| Path                        | Purpose                                                                                   |
| --------------------------- | ----------------------------------------------------------------------------------------- |
| `SKILL.md`                  | Agent skill entry point and planned workflow                                              |
| `templates/current.md.hbs`  | Current journal entries                                                                   |
| `templates/daily.md.hbs`    | Daily summary and session details                                                         |
| `templates/weekly.md.hbs`   | Weekly summary and daily links                                                            |
| `templates/monthly.md.hbs`  | Monthly summary                                                                           |
| `templates/historic.md.hbs` | Historical summary and monthly links                                                      |
| `templates/config.toml.hbs` | Vault location, date/time formats, and authorized directory placeholders                  |
| `schemas/config.json`       | Configuration schema                                                                      |
| `scripts/install.lua`       | Interactive vault configuration installer                                                 |
| `scripts/sync.lua`          | Pull and roll the current day into the archive                                            |
| `scripts/weekly.lua`        | Create and link completed weekly summaries                                                |
| `scripts/monthly.lua`       | Create and link completed monthly summaries                                               |
| `scripts/history.lua`       | Update the historical month index                                                         |
| `scripts/entry.lua`         | Append a validated entry to today's journal                                               |
| `scripts/publish.lua`       | Publish selected daily, weekly, monthly, history, or entry files with remote race retries |

Templates use `{{...}}` placeholders and `{{#each ...}}` blocks. They are source
templates rather than rendered vault notes. Run the installer as described in
`SKILL.md` to create or repair `.journal.config.toml` in a vault.

## Journal content

Session templates capture the time, session hash, agent, host, work performed,
working directory, affected files, verification, and pending items. Summary
templates provide links between daily, weekly, and monthly notes using Obsidian
wiki-links.

The workflow in `SKILL.md` uses Lua for file changes and Git operations. Agents
write factual summary prose after the script creates the linked structure.

Run the Lua checks with Lua, Taplo, and Git available on `PATH`:

```sh
lua tests/install.lua
lua tests/journal.lua
```

## Development

Make `pre-commit` and Nix available in your development environment, then run:

```sh
pre-commit install
pre-commit run --all-files
```

The configuration installs both `pre-commit` and `commit-msg` hooks. Prettier
formats HTML/Handlebars `.hbs` files with its built-in `glimmer` parser and
two-space indentation. `.prettierignore` protects compound `.md.hbs` and
`.toml.hbs` templates from both editor formatting and the Prettier hook, because
formatting them as HTML corrupts their Markdown or TOML structure.

File checks validate YAML, JSON, and TOML; detect merge markers,
case-conflicting paths, and private keys; reject newly added files larger than
500 KB; and fix final newlines and trailing whitespace while preserving Markdown
line breaks. Markdownlint checks Markdown. The Luacheck hook invokes Nix, which
downloads and caches Luacheck when needed; neither Luacheck nor LuaRocks needs
to be installed on the host.

### Formatting

Prettier writes formatting changes to JSON, Markdown, YAML, TOML, Lua, shell,
and HTML/Handlebars `.hbs` files. After a hook modifies files, review and stage
them again before retrying the commit.

EditorConfig defines UTF-8, LF line endings, final newlines, and two-space
indentation, with four spaces for Python. Markdown wraps prose at 80 columns and
leaves embedded code examples unchanged. Python has no formatter configured.

Prettier and its pinned Lua, shell, and TOML plugins run in an isolated
`pre-commit` environment. Plugins load only for matching file types; JSON uses
native Prettier support. The Lua plugin is experimental, so review its output
when formatting existing scripts.

Formatting on save is an editor setting, separate from Git hooks. In Neovim,
configure Conform with `format_on_save` and a Prettier formatter. Editor
formatting of Lua, shell, or TOML also requires the corresponding plugin from
`.prettierrc.yaml` to be available to that Prettier installation.

### Markdown style

Markdownlint enables its default checks and fixes the project style: ATX
headings (`## Heading`), dash bullets, two-space nested lists, ordered lists
numbered sequentially or with repeated `1.`, `---` thematic breaks, fenced code
blocks with backticks, underscores for emphasis, and double asterisks for strong
emphasis. Prettier wraps prose at 80 columns, normalizes whitespace and tables,
and preserves embedded code examples. Long links, tables, and code may exceed 80
columns, so Markdownlint's separate line-length check is disabled. Code fences
require a language, and headings must follow a consistent hierarchy.

Both tools run through pre-commit. Compound `.md.hbs` templates are excluded
from Prettier formatting.

### Spell checking

`cspell.config.yaml` uses English plus bundled programming language, software,
company, file type, and npm dictionaries. Project-specific terms belong in its
`words` list. It respects `.gitignore` and excludes `templates/` and `.git/`.
CSpell-compatible editors can discover the configuration automatically. With
CSpell available, check files with `cspell lint --config cspell.config.yaml .`.
CSpell also runs as a pre-commit hook on text files, using a pinned version in
an isolated Node environment. Run it independently with
`pre-commit run cspell --all-files`.

### Commit messages

Commitlint enforces Conventional Commits using
`@commitlint/config-conventional`:

```text
feat(journal): add daily entries
fix: preserve existing notes
docs: explain configuration
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, validation, and pull request
requirements. Participation is covered by the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License

Licensed under the [MIT License](LICENSE).
