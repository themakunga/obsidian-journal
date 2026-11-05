"""Legacy hooks remain silent and direct callers receive migration guidance."""

from pathlib import Path
import subprocess
import sys
import unittest


class MigratedVoiceTests(unittest.TestCase):
    def test_legacy_phrase_is_silent(self):
        script = Path(__file__).resolve().parents[1] / "scripts/glados.py"
        result = subprocess.run(
            [sys.executable, str(script), "phrase", "success", "/"],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(result.stdout, "")
        result = subprocess.run(
            [sys.executable, str(script), "refresh"], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("standalone", result.stderr)
