# GLaDOS for Obsidian Journal

## TTS configuration

Use the local `glados-say` command provided by the Nix `glados-tts` application
(`my.apps.glados-tts.enable = true`). It runs Piper with the pinned medium
GLaDOS voice from DavesArmoury, model `glados_piper_medium.onnx`, revision
`b64622ad52f15804249f7f08a4c268b5e82c6969`. Nix supplies the Piper executable,
model path, and audio player to the command. It uses `afplay` on macOS and `mpv`
on Linux. The model hash is
`sha256-s1oH+m/HiOxK1jfsmLdNZvBuZku7Q2a0A10d6qwzCNM=`; its JSON configuration
hash is `sha256-d6EDN3yXHoe/rGqDm+sN6VQz84rPH7ksIB3Nxyhi9CI=`. No remote speech
service is used.

Enable journal announcements in the vault's `.journal.config.toml`:

```toml
[glados]
enable = true
command = "glados-say"
```

The installer asks whether to enable GLaDOS and defaults to disabled. Python
3.11 or newer and `uv` are needed for `scripts/glados.py`. The skill keeps its
PyYAML dependency in its own `uv`-managed `.venv`.

## Coding-agent hooks

Journal announcements run from the journal scripts. Codex status speech runs
from separate lifecycle hooks; enabling `[glados]` does not install those hooks.
When the user requests status speech, reuse the existing installer from the
`nix-systems` checkout:

```sh
python3 modules/applications/glados-tts/install-hooks.py /path/to/nix-built/bin
```

Pass the directory containing the Nix-built `glados-hook` and `glados-say`
executables, such as a Nix system profile. Each command's individual package
directory may contain only that command. The installer merges Codex and Claude
hooks, preserves other settings, and keeps backups. Inspect
`~/.codex/hooks.json` for `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`,
and `Stop` handlers. In Codex, review the installed definitions through
`/hooks`, then start a new session. Codex skips new or changed hooks until the
user trusts them; leave its trust records to Codex. See the
[official hook documentation](https://learn.chatgpt.com/docs/hooks).

For missing audio, check journal enablement, the applicable lifecycle hooks, and
`~/.config/glados-tts/muted` separately. Test `glados-say` only when voice is
authorized. A successful configuration check does not verify audio playback.

## Behavior

- An agent can read a file or list a directory only when it falls under an
  `authorized_dirs` entry whose `enable` is `true`. Use
  `uv run --project . python scripts/glados.py context /absolute/path`; file
  reads are limited to text files of 16 KiB or less.
- Automatic coding-agent speech runs only at completion, at most once every 90
  seconds per session, within an enabled `authorized_dirs` directory. Starts,
  tool calls and approval requests are silent.
- Speech selects a short English catalog phrase scoped to the working directory
  with `uv run --project . python scripts/glados.py speak success`. Custom
  `--message` text is accepted for existing callers but is not spoken. Without
  an enabled directory or matching phrase, remain silent; there is no generic
  fallback. `glados.py phrase success /absolute/path` selects text without
  audio.
- Journal success speech runs only after the task commit and push succeed and
  follows the same directory filter. Report failures in text. Speech errors do
  not undo a successful push.
- On each daily `sync.lua`, GLaDOS reads Work and Files from the previous seven
  archived daily entries, using only entries whose CWD or Files point inside an
  enabled `authorized_dirs` directory. It rebuilds `.glados/phrases.yaml` as a
  YAML list from `templates/glados-phrases.json`, adding phrases for active
  directory topics and dropping general or stale phrases. The daily publish
  includes this file automatically when GLaDOS is enabled. Each list item
  records its UUID, phrase, event, topic, enabled state, dates, and project
  scope. `schemas/glados-phrases.json` describes that record shape.

The model is trained in English. Every topic keeps GLaDOS dry, sarcastic
personality in one or two short sentences. Automatic speech uses the scoped
catalog; written replies carry the task details.
