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

## Behavior

- An agent can read a file or list a directory only when it falls under an
  `authorized_dirs` entry whose `enable` is `true`. Use
  `uv run --project . python scripts/glados.py context /absolute/path`; file
  reads are limited to text files of 16 KiB or less.
- Agents supply a short English message related to the user's request with
  `uv run --project . python scripts/glados.py speak start --message "..."`. The
  `decision` event has saved confirmation phrases when no custom message is
  supplied.
- Journal success speech runs only after the task commit and push succeed.
  Failures announce the failed operation and instruct the agent to report the
  error and the corrective step. Speech errors do not undo a successful push.
- On each daily `sync.lua`, GLaDOS reads Work and Files from the previous seven
  archived daily entries. It rebuilds `.glados/phrases.yaml` as a YAML list from
  the phrase bank in `templates/glados-phrases.json`, adding phrases for active
  topics and dropping phrases for topics that have aged out. The daily publish
  includes this file automatically when GLaDOS is enabled. Each list item
  records its UUID, phrase, event, topic, enabled state, dates, and project
  scope. `schemas/glados-phrases.json` describes that record shape.

The model is trained in English. Keep spoken messages brief; the agent should
summarize the actual request or result instead of reading the full response.
