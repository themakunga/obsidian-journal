---
name: obsidian-journal
description: Create or update journal entries in an Obsidian vault when the user asks to record notes or work.
created_at: 2026-10-25T17:00:00
updated_at: 2026-10-25T22:00:00
owner: TheMakunga
repo: obsidian-journal
---

# Obsidian Journal

## Description

this is a rollup to silently register agent sessions into an obsidian vault

---

## Configuration

on install this plugin on your code agent,

## Installation

## Directory Layout

```plain
[vault]/                ← vault absolute path
  journal-current.md    ← today's active file (only one at root)
  journal/              ← journal base directory
    history.md          ← historic summary
    YYYY-Www/           ← weekly directory
      YYYY-MM-DD.md     ← previous archived daily
      summary.md        ← weekly summary
    monthly/            ← monthly directory
      YYYY-MM.md        ← monthly summary
```

## Steps

### 1 - Sync and get last changes

### 2 - Fill Weekly Summary

### 3 - Fill Monthly Summary

### 4 - Fill History Summary

### 5 - Write entry

### 6 - Commit and push Entry

## Guardrails

## Permissions

## Extras
