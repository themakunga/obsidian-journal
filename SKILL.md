---
name: obsidian-journal
description: Record agent work in an Obsidian vault and maintain daily, weekly, monthly, and historical journals.
created_at: 2026-10-25T17:00:00
updated_at: 2026-10-25T22:00:00
owner: TheMakunga
repo: obsidian-journal
---

# Obsidian Journal

## Description

this is a rollup to silently register agent sessions into an obsidian vault

---

## Installation

Lua and Taplo must be on `PATH`. Taplo validates TOML against
`schemas/config.json`. When enabling GLaDOS, Python 3.11+, `uv`, and the local
`glados-say` command are also required. `uv` creates the skill's `.venv` and
installs its Python dependencies from `pyproject.toml`.

```sh
lua scripts/install.lua
```

The installer asks for an existing absolute vault path. That directory becomes
the base for the journal and for `.journal.config.toml`. It records the selected
path in `~/.obsidian-journal-vault` for subsequent runs. If the configuration is
missing, invalid according to the schema, or points to another vault, it asks
for the required values and writes a validated configuration. It saves an
existing configuration as `.journal.config.toml.invalid-YYYYMMDDHHMMSS` before
replacing it. A valid configuration for the selected vault is left intact. The
installer also asks whether to enable local GLaDOS TTS. See
[glados.md](glados.md) for the voice configuration, authorized context access,
speech events, and daily phrase refresh behavior.

## Directory Layout

```plain
[vault]/                ← vault absolute path
  .journal.config.toml  ← validated installation configuration
  .glados/phrases.yaml     ← daily generated phrase list when enabled
  journal-current.md    ← today's active file (only one at root)
  README.md             ← journal overview
  history.md            ← historic summary
  weekly/               ← weekly directory
    YYYY-Www/           ← one directory per ISO week
      YYYY-MM-DD.md     ← previous archived daily
      summary.md        ← weekly summary
  monthly/              ← monthly directory
    YYYY-MM.md          ← monthly summary
```

## Available templates

All templates are available at `./templates` no other dir must be used for that
work, that includes external templates, if is needed a new one, ask the user to
create it, push the changes of the skill and update it in the agents as
necessary.

| Filename          | Description                                                                           |
| ----------------- | ------------------------------------------------------------------------------------- |
| `config.toml.hbs` | configuration template validated against `../schemas/config.json`                     |
| `current.md.hbs`  | current day template file, for the `journal-current.md` file on the root of the vault |
| `daily.md.hbs`    | previous day summary and history file                                                 |
| `weekly.md.hbs`   | weekly summary                                                                        |
| `monthly.md.hbs`  | monthly summary                                                                       |
| `historic.md.hbs` | historical summary                                                                    |

## Steps

### 1 - Sync and get last changes

Run from the skill directory:

```sh
lua scripts/sync.lua
```

`sync.lua` reads the vault selected at installation, validates its
configuration, pulls its Git branch with `--ff-only`, archives an older
`journal-current.md`, and creates today's current file. It never replaces an
existing archive. If GLaDOS is enabled, it also refreshes phrases from Work and
Files in the last seven archived daily entries. The vault must be the root of a
Git repository with an upstream branch.

Fill `## Summary` in each newly archived daily file from its entries. Review the
files, then commit and push only the daily rollover paths:

```sh
lua scripts/publish.lua daily journal-current.md weekly/2026-W43/2026-10-25.md
```

Omit the archive path when no day was archived. Publish this daily task before
appending a new entry to `journal-current.md`.

### 2 - Fill Weekly Summary

Run `lua scripts/weekly.lua`. Read the linked archived days in each new or
updated `weekly/YYYY-Www/summary.md`. Fill its `## Summary` with verified work,
decisions, failures, and pending items. Preserve existing prose and links.
Commit and push each changed weekly summary as a weekly task:

```sh
lua scripts/publish.lua weekly weekly/2026-W43/summary.md
```

### 3 - Fill Monthly Summary

Run `lua scripts/monthly.lua`. For each new or updated `monthly/YYYY-MM.md`,
read its linked weekly summaries and fill `## Summary` with a factual overview.
A month is created after all its linked weeks have summaries. Commit and push
changed monthly summaries separately:

```sh
lua scripts/publish.lua monthly monthly/2026-10.md
```

### 4 - Fill History Summary

Run `lua scripts/history.lua`. Read `history.md` and the linked monthly
summaries. Fill or update its `## Summary` using only completed months. Keep
existing month links and prose. Commit and push the history task separately:

```sh
lua scripts/publish.lua history history.md
```

### 5 - Write entry

Write one complete Markdown entry, then append it with the configured agent
name:

```sh
lua scripts/entry.lua Codex < /tmp/entry.md
```

The entry must start with
`### <configured time> - <short hex hash> - <agent> - <host>` and contain
`**Work:**`, `**CWD:**`, `**Files:**`, `**Verification:**`, and `**Pending:**`.
Put each Work and Files item on its own bullet line, starting with a hyphen and
a space; use `- none` when a section has no files. The template placeholders
represent one item, with any additional items written as further bullet lines.
Use the configured time format and an actual session hash when available. Do not
invent measurements or verification results. `entry.lua` rejects duplicate
headings and appends to today's current file.

### 6 - Commit and push Entry

Review today's entry, then commit and push only `journal-current.md` as an entry
task:

```sh
lua scripts/publish.lua entry journal-current.md
```

`publish.lua` accepts only paths for its declared task type. It publishes from
an isolated checkout of the latest remote branch, combines concurrent edits to
the same journal file, and retries a push rejected by another host. It then
fast-forwards the local branch while preserving unrelated staged files. Each
task gets its own commit message. Conflicting prose is retained from both hosts,
so review summaries when agents edit the same paragraph.

When GLaDOS is enabled, daily publication also includes `.glados/phrases.yaml`.
It announces success only after the commit and push. On failure, it speaks the
failed operation and prints the error needed to correct it. Agents can use
`uv run --project . python scripts/glados.py context PATH` to read a file under
an enabled `authorized_dirs` entry and supply a short, request-specific speech
message with
`uv run --project . python scripts/glados.py speak EVENT --message TEXT`. Any
spoken message about a task must briefly describe the user's actual request or
its result; generic saved phrases are for confirmations and fallback
notifications.

## Guardrails

- Keep factual summaries tied to existing entries. The Lua script creates
  structure and links; the agent supplies prose from source notes.
- Do not overwrite existing archives or commit unrelated vault changes.
- Publish pending local journal edits before running `sync.lua` again. Existing
  unpublished local commits or remote permissions errors still need manual
  attention.

## Permissions

Once this skill is enabled and its vault configuration is valid, journal
maintenance is standing-authorized. Run the daily rollover, weekly, monthly, and
history updates, append session entries, and perform their scoped Git fetches,
commits, and pushes without asking for permission. When GLaDOS is enabled, speak
the journal result only after its commit and push; report failures that need
user action.

If the user asks that a session not be recorded, do not create, append, commit,
or push a journal entry for that session. Respect that request without asking
for confirmation.

## Extras
