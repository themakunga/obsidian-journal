"""Verify host-local configuration without changing the shared vault config."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class LocalConfigTest(unittest.TestCase):
    def test_local_config_precedence_installer_and_legacy_fallback(self):
        skill = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home, vault = root / "home", root / "vault"
            home.mkdir()
            vault.mkdir()
            (home / ".obsidian-journal-vault").write_text(str(vault) + "\n")
            shared = vault / ".journal.config.toml"
            shared.write_text(self.config("/another-host/journal"))
            original = shared.read_bytes()
            local = home / ".config/obsidian-journal/config.toml"
            local.parent.mkdir(parents=True)
            local.write_text(self.config(str(vault)))
            env = dict(os.environ, HOME=str(home), PWD=str(skill))
            probe = (
                f'arg = {{[0] = "{skill}/scripts/probe.lua"}}; '
                f'local journal = dofile("{skill}/scripts/journal_util.lua"); '
                'io.write(journal.config)'
            )
            loaded = subprocess.run(["lua", "-e", probe], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(loaded.returncode, 0, loaded.stderr)
            self.assertEqual(loaded.stdout, str(local))
            installed = subprocess.run(
                ["lua", "scripts/install.lua"], cwd=skill, env=env,
                input=str(vault) + "\n", capture_output=True, text=True,
            )
            self.assertEqual(installed.returncode, 0, installed.stderr)
            self.assertEqual(shared.read_bytes(), original)
            local.unlink()
            fresh = subprocess.run(
                ["lua", "scripts/install.lua"], cwd=skill, env=env,
                input=str(vault) + "\n" * 7, capture_output=True, text=True,
            )
            self.assertEqual(fresh.returncode, 0, fresh.stderr)
            self.assertTrue(local.is_file())
            self.assertEqual(shared.read_bytes(), original)
            shared.write_text(self.config(str(vault)))
            local.write_text("invalid = true\n")
            invalid = subprocess.run(["lua", "-e", probe], env=env,
                                     capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            local.unlink()
            fallback = subprocess.run(["lua", "-e", probe], env=env,
                                      capture_output=True, text=True)
            self.assertEqual(fallback.returncode, 0, fallback.stderr)
            self.assertEqual(fallback.stdout, str(shared))

    @staticmethod
    def config(vault):
        return (
            'authorized_dirs = []\n[core]\nname = "test"\n'
            f'path = "{vault}"\n[configuration]\n'
            'date_format = "yyyy-MM-dd"\ntime_format = "HH:mm"\n'
            'agents = ["Codex"]\n'
        )


if __name__ == "__main__":
    unittest.main()
