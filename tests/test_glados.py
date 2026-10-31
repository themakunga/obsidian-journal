"""Run with python -m unittest discover -s tests -p 'test_glados.py'."""

from datetime import date, timedelta
import importlib.util
from pathlib import Path
import tempfile
import unittest
import uuid
from unittest.mock import patch

import yaml

spec = importlib.util.spec_from_file_location(
    "glados", Path(__file__).resolve().parents[1] / "scripts/glados.py"
)
glados = importlib.util.module_from_spec(spec)
spec.loader.exec_module(glados)


class ScopedPhrases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.project = self.root / "project"
        self.project.mkdir()
        self.other = self.root / "project-other"
        self.other.mkdir()
        self.vault = self.root / "journal"
        self.vault.mkdir()
        self.config = {
            "glados": {"enable": True, "command": "/fake/glados-say"},
            "authorized_dirs": [{"enable": True, "path": str(self.project)}],
        }
        self.home = patch.object(Path, "home", return_value=self.root)
        self.home.start()
        self.addCleanup(self.home.stop)
        self.archive = self.vault / "weekly/2026-W01"
        self.archive.mkdir(parents=True)

    def entry(self, cwd, work):
        return f"### 10:00 - abc123 - Codex - test\n\n**Work:**\n- {work}\n\n**CWD:** `{cwd}`\n\n**Files:**\n- none\n\n**Verification:** checked\n"

    def refresh(self, text):
        day = date.today() - timedelta(days=1)
        (self.archive / f"{day}.md").write_text(text)
        glados.refresh(self.vault, self.config)
        return yaml.safe_load((self.vault / ".glados/phrases.yaml").read_text())

    def test_catalog_uses_only_enabled_directory_activity(self):
        records = self.refresh(
            self.entry(self.project, "Changed the Python script.")
            + self.entry(self.other, "Deploy Nix packages and tests.")
        )
        self.assertTrue(records)
        self.assertEqual({item["topic"] for item in records}, {"code"})
        self.assertTrue(all(item["project"] == {
            "is_project": True, "path": str(self.project)
        } for item in records))

    def test_no_matching_activity_means_silence(self):
        self.assertEqual(self.refresh(self.entry(self.other, "Python script")), [])
        with patch.object(glados.subprocess, "run") as run:
            with patch.object(glados, "load_config", return_value=(self.vault, self.config)):
                with patch.object(Path, "cwd", return_value=self.project):
                    glados.speak(self.config, "success", "A long generic announcement.")
        run.assert_not_called()

    def test_scope_checked_at_playback_and_custom_prose_is_not_spoken(self):
        records = self.refresh(self.entry(self.project, "Python script"))
        pool = {item["phrase"] for item in records if item["event"] == "success"}
        with patch.object(glados, "load_config", return_value=(self.vault, self.config)):
            with patch.object(glados.subprocess, "run") as run:
                with patch.object(Path, "cwd", return_value=self.project):
                    glados.speak(self.config, "success", "A long generic announcement.")
                self.assertIn(run.call_args.args[0][1], pool)
                run.reset_mock()
                with patch.object(Path, "cwd", return_value=self.other):
                    glados.speak(self.config, "success", "Generic")
                run.assert_not_called()
                self.config["authorized_dirs"][0]["enable"] = False
                with patch.object(Path, "cwd", return_value=self.project):
                    glados.speak(self.config, "success", "Generic")
                run.assert_not_called()

    def test_symlink_cannot_escape_scope(self):
        escape = self.project / "escape"
        escape.symlink_to(self.other, target_is_directory=True)
        self.assertEqual(self.refresh(self.entry(escape, "Python script")), [])

    def test_files_can_link_activity_to_an_enabled_directory(self):
        text = self.entry(self.other, "Python script").replace(
            "- none", f"- `{self.project / 'removed.py'}`"
        )
        self.assertTrue(self.refresh(text))

    def test_disabled_voice_and_stale_general_catalog_are_silent(self):
        records = self.refresh(self.entry(self.project, "Python script"))
        self.config["glados"]["enable"] = False
        self.assertEqual(glados.select_phrase(self.vault, self.config, "success", self.project), "")
        self.config["glados"]["enable"] = True
        for item in records:
            item["project"] = {"is_project": False}
        (self.vault / ".glados/phrases.yaml").write_text(yaml.safe_dump(records))
        self.assertEqual(glados.select_phrase(self.vault, self.config, "success", self.project), "")

    def test_refresh_preserves_disabled_phrases(self):
        text = self.entry(self.project, "Python script")
        records = self.refresh(text)
        records[0]["enable"] = False
        path = self.vault / ".glados/phrases.yaml"
        path.write_text(yaml.safe_dump(records))
        self.assertFalse(self.refresh(text)[0]["enable"])

    def test_consecutive_phrases_differ_when_alternatives_exist(self):
        self.refresh(self.entry(self.project, "Changed a Python script and Nix package."))
        first = glados.select_phrase(self.vault, self.config, "success", self.project)
        second = glados.select_phrase(self.vault, self.config, "success", self.project)
        self.assertTrue(first)
        self.assertNotEqual(first, second)

    def test_migration_preserves_disabled_legacy_phrases(self):
        text = self.entry(self.project, "Python script")
        records = self.refresh(text)
        old = records[0]
        old["id"] = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{old['topic']}:{old['event']}:{old['phrase']}"))
        old["enable"] = False
        old["project"] = {"is_project": False}
        (self.vault / ".glados/phrases.yaml").write_text(yaml.safe_dump([old]))
        self.assertFalse(self.refresh(text)[0]["enable"])


if __name__ == "__main__":
    unittest.main()
