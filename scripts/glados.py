#!/usr/bin/env python3
"""Journal-aware GLaDOS voice and phrase maintenance."""

from datetime import date, datetime, timedelta, timezone
import json
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import uuid

import yaml


SKILL = Path(__file__).resolve().parents[1]
PHRASE_SOURCE = SKILL / "templates/glados-phrases.json"
EVENTS = ("start", "notify", "decision", "success", "failure")
ENTRY_TEXT = re.compile(
    r"(?ms)^\*\*(?:Work|Files):\*\*\s*(.*?)(?=^\*\*[A-Za-z]+:\*\*|^### |\Z)"
)


def load_config():
    pointer = Path.home() / ".obsidian-journal-vault"
    vault = Path(pointer.read_text().strip()).resolve(strict=True)
    config = tomllib.loads((vault / ".journal.config.toml").read_text())
    return vault, config


def phrase_data():
    return json.loads(PHRASE_SOURCE.read_text())


def phrase_records(source, projects, existing):
    old = {
        item["id"]: item
        for item in existing
        if isinstance(item, dict) and "id" in item
    }
    records = []
    today = datetime.now(timezone.utc).isoformat(timespec="seconds")
    for root, topic in projects:
        details = source["topics"][topic]
        groups = details["phrases"]
        for event, phrases in groups.items():
            for phrase in phrases:
                identifier = str(
                    uuid.uuid5(uuid.NAMESPACE_URL, f"{root}:{topic}:{event}:{phrase}")
                )
                legacy = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{topic}:{event}:{phrase}"))
                previous = old.get(identifier, old.get(legacy, {}))
                records.append(
                    {
                        "id": identifier,
                        "phrase": phrase,
                        "event": event,
                        "topic": topic,
                        "enable": previous.get("enable", True),
                        "created_at": previous.get("created_at", today),
                        "updated_at": previous.get("updated_at", today),
                        "project": {"is_project": True, "path": str(root)},
                    }
                )
    return records


def refresh(vault, config):
    if not config.get("glados", {}).get("enable", False):
        return
    today = date.today()
    recent = []
    for path in vault.glob("weekly/????-W??/????-??-??.md"):
        try:
            day = date.fromisoformat(path.stem)
        except ValueError:
            continue
        if today - timedelta(days=7) <= day < today:
            recent.append(path)
    activity = {root: [] for root in enabled_roots(config)}
    for path in sorted(recent):
        for entry in re.split(r"(?m)^### ", path.read_text(errors="replace"))[1:]:
            fields = " ".join(match.group(1) for match in ENTRY_TEXT.finditer(entry))
            cwd = re.findall(r"(?m)^\*\*CWD:\*\*\s*`([^`]+)`", entry)
            files = [match.group(1) for match in ENTRY_TEXT.finditer(entry)
                     if match.group(0).startswith("**Files:")]
            paths = [Path(name).resolve() for name in cwd + re.findall(r"`(/[^`\n]+)`", " ".join(files))]
            for root in activity:
                if any(within_root(candidate, root) for candidate in paths):
                    activity[root].append(fields.lower())
    source = phrase_data()
    topics = []
    for root, entries in activity.items():
        for topic, details in source.get("topics", {}).items():
            if any(
                re.search(rf"\b{re.escape(word)}\b", " ".join(entries))
                for word in details["keywords"]
            ):
                topics.append((root, topic))
    destination = vault / ".glados/phrases.yaml"
    existing = yaml.safe_load(destination.read_text()) if destination.exists() else []
    records = phrase_records(source, sorted(topics), existing or [])
    encoded = yaml.safe_dump(records, allow_unicode=True, sort_keys=False)
    if destination.exists() and destination.read_text() == encoded:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=destination.parent, prefix=".glados-")
    with os.fdopen(fd, "w") as stream:
        stream.write(encoded)
    os.replace(name, destination)


def enabled_roots(config):
    for item in config.get("authorized_dirs", []):
        if item.get("enable") is not True:
            continue
        try:
            root = Path(item["path"]).resolve(strict=True)
        except (KeyError, OSError):
            continue
        if root.is_dir():
            yield root


def within_root(candidate, root):
    # samefile also handles differently cased paths on case-insensitive volumes.
    return any(
        parent == root or (parent.exists() and parent.samefile(root))
        for parent in (candidate, *candidate.parents)
    )


def allowed_root(config, requested):
    candidate = Path(requested).resolve(strict=True)
    if any(within_root(candidate, root) for root in enabled_roots(config)):
        return candidate
    raise ValueError("Path is outside enabled authorized_dirs in .journal.config.toml")


def read_context(config, requested):
    if not config.get("glados", {}).get("enable", False):
        raise ValueError("GLaDOS is disabled in .journal.config.toml")
    target = allowed_root(config, requested)
    if target.is_dir():
        for path in sorted(target.iterdir()):
            if not path.name.startswith("."):
                print(("dir " if path.is_dir() else "file ") + str(path))
        return
    if target.stat().st_size > 16384 or target.suffix.lower() not in {
        ".md", ".txt", ".toml", ".yaml", ".yml", ".json", ".lua", ".py", ".sh", ".nix"
    }:
        raise ValueError("Only text files up to 16 KiB can be read for GLaDOS context")
    content = target.read_text(encoding="utf-8")
    if "\0" in content:
        raise ValueError("Binary files cannot be read for GLaDOS context")
    sys.stdout.write(content)


def select_phrase(vault, config, event, cwd):
    if not config.get("glados", {}).get("enable", False):
        return ""
    if event not in EVENTS:
        raise ValueError("Unknown speech event: " + event)
    try:
        candidate = allowed_root(config, cwd)
    except (OSError, ValueError):
        return ""
    catalog = vault / ".glados/phrases.yaml"
    records = yaml.safe_load(catalog.read_text()) if catalog.is_file() else []
    pool = []
    for item in records or []:
        project = item.get("project", {})
        if item.get("enable") is not True or item.get("event") != event or project.get("is_project") is not True:
            continue
        try:
            root = allowed_root(config, project["path"])
        except (KeyError, OSError, ValueError):
            continue
        phrase = item.get("phrase")
        if within_root(candidate, root) and isinstance(phrase, str) and 0 < len(phrase) <= 160:
            pool.append(phrase)
    if not pool:
        return ""
    last_file = Path.home() / ".config/glados-tts" / f"journal-last-{event}.txt"
    try:
        last = last_file.read_text()
    except OSError:
        last = ""
    phrase = random.choice([item for item in pool if item != last] or pool)
    try:
        last_file.parent.mkdir(parents=True, exist_ok=True)
        last_file.write_text(phrase)
    except OSError:
        pass
    return phrase


def speak(config, event, _message):
    vault, _ = load_config()
    message = select_phrase(vault, config, event, Path.cwd())
    if not message:
        return
    command = config.get("glados", {}).get("command", "glados-say")
    executable = shutil.which(command) if not Path(command).is_absolute() else command
    if not executable:
        raise FileNotFoundError(f"GLaDOS command is not installed: {command}")
    subprocess.run([executable, message], check=True, timeout=1800)


def merge_phrases(base_path, ours_path, theirs_path):
    base, ours, theirs = [
        {item["id"]: item for item in yaml.safe_load(Path(path).read_text()) or []}
        for path in (base_path, ours_path, theirs_path)
    ]
    keep = (
        (ours.keys() | theirs.keys())
        - (base.keys() - ours.keys())
        - (base.keys() - theirs.keys())
    )
    result = {
        identifier: ours[identifier] if identifier in ours else theirs[identifier]
        for identifier in keep
    }
    sys.stdout.write(yaml.safe_dump(list(result.values()), allow_unicode=True, sort_keys=False))


def main(argv):
    if not argv:
        raise ValueError("Usage: glados.py refresh|phrase|speak|context|merge-phrases ...")
    if argv[0] == "merge-phrases" and len(argv) == 4:
        merge_phrases(*argv[1:])
        return
    vault, config = load_config()
    if argv[0] == "refresh" and len(argv) == 1:
        refresh(vault, config)
    elif argv[0] == "phrase" and len(argv) == 3:
        print(select_phrase(vault, config, argv[1], argv[2]))
    elif argv[0] == "context" and len(argv) == 2:
        read_context(config, argv[1])
    elif argv[0] == "speak" and len(argv) >= 2:
        event = argv[1]
        message = ""
        if len(argv) > 2:
            if argv[2] != "--message" or len(argv) != 4:
                raise ValueError("Usage: glados.py speak EVENT [--message TEXT]")
            message = argv[3]
        speak(config, event, message)
    else:
        raise ValueError("Usage: glados.py refresh|phrase|speak|context|merge-phrases ...")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (
        OSError,
        ValueError,
        KeyError,
        tomllib.TOMLDecodeError,
        yaml.YAMLError,
        subprocess.SubprocessError,
    ) as error:
        print(f"GLaDOS: {error}", file=sys.stderr)
        sys.exit(1)
