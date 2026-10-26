# Obsidian Journal

An agent skill for recording work sessions in an Obsidian vault, with templates for daily entries and weekly, monthly, and historical summaries.

The project is under development. This repository currently provides the skill outline, journal templates, a configuration template, a draft configuration schema, and development tooling. Automated rendering, rollups, and Git synchronization are not implemented here yet.

## Repository layout

| Path                             | Purpose                                                                  |
| -------------------------------- | ------------------------------------------------------------------------ |
| `SKILL.md`                       | Agent skill entry point and planned workflow                             |
| `templates/current.template.md`  | Current journal entries                                                  |
| `templates/daily.template.md`    | Daily summary and session details                                        |
| `templates/weekly.template.md`   | Weekly summary and daily links                                           |
| `templates/monthly.template.md`  | Monthly summary                                                          |
| `templates/historic.template.md` | Historical summary and monthly links                                     |
| `templates/config.template.toml` | Vault location, date/time formats, and authorized directory placeholders |
| `schmas/config.json`             | Draft configuration schema                                               |

Templates use `{{...}}` placeholders and `{{#each ...}}` blocks. They are source templates rather than rendered vault notes. The configuration template and draft schema still need to be aligned before automated validation can be used.

## Journal content

Session templates capture the time, session hash, agent, host, work performed, working directory, affected files, verification, and pending items. Summary templates provide links between daily, weekly, and monthly notes using Obsidian wiki-links.

The planned workflow in `SKILL.md` covers synchronization, summary maintenance, entry creation, and committing and pushing entries. Its implementation is still pending.

## Development

Make `pre-commit` and `luacheck` available in your development environment, then run:

```sh
pre-commit install
pre-commit run --all-files
```

The configuration installs both `pre-commit` and `commit-msg` hooks. All file checks exclude `templates/`, including its subdirectories, so template placeholders and layout remain untouched.

File checks validate YAML, JSON, and TOML; detect merge markers, case-conflicting paths, and private keys; reject newly added files larger than 500 KB; and fix final newlines and trailing whitespace while preserving Markdown line breaks. Markdownlint checks Markdown, and Luacheck checks Lua using the executable on `PATH`.

### Formatting

Prettier writes formatting changes to JSON, Markdown, YAML, TOML, Lua, and shell files. After a hook modifies files, review and stage them again before retrying the commit.

EditorConfig defines UTF-8, LF line endings, final newlines, and two-space indentation, with four spaces for Python. Markdown preserves prose line breaks and leaves embedded code examples unchanged. Python has no formatter configured.

Prettier and its pinned Lua, shell, and TOML plugins run in an isolated `pre-commit` environment. Plugins load only for matching file types; JSON uses native Prettier support. The Lua plugin is experimental, so review its output when formatting existing scripts.

Formatting on save is an editor setting, separate from Git hooks. In Neovim, configure Conform with `format_on_save` and a Prettier formatter. Editor formatting of Lua, shell, or TOML also requires the corresponding plugin from `.prettierrc.yaml` to be available to that Prettier installation.

### Commit messages

Commitlint enforces Conventional Commits using `@commitlint/config-conventional`:

```text
feat(journal): add daily entries
fix: preserve existing notes
docs: explain configuration
```
