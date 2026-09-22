import os
from pathlib import Path
import subprocess
import tempfile
import unittest


TOOLCHAIN = "rfidresearchgroup/proxmark3/arm-none-eabi-gcc"


class ToolchainPlanChecks(unittest.TestCase):
    def plan(self, tap, formulae, *, bottled=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "brew").write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$CALLS"
if [[ "$1 $2" == 'ruby -e' && "$3" == *bottle_specification* ]]; then
  exit "$BOTTLED_RESULT"
fi
''')
            (root / "brew").chmod(0o755)
            output = root / "outputs"
            calls = root / "calls"
            script = Path(__file__).with_name("prepare-toolchain.sh").resolve()
            subprocess.run(["bash", str(script)], check=True, cwd=root, env=dict(
                os.environ, PATH=f"{root}:{os.environ['PATH']}", TAP_NAME=tap,
                TESTING_FORMULAE=",".join(formulae), ADDED_FORMULAE=",".join(formulae),
                DELETED_FORMULAE="", GITHUB_OUTPUT=str(output), RUNNER_TEMP=str(root),
                CALLS=str(calls), BOTTLED_RESULT="0" if bottled else "1",
            ), capture_output=True, text=True)
            return dict(line.split("=", 1) for line in output.read_text().splitlines()), (
                calls.read_text() if calls.exists() else "")

    def test_owning_tap_builds_missing_compiler_in_same_batch(self):
        firmware = "rfidresearchgroup/proxmark3/proxmark-firmware-rdv4"
        result, calls = self.plan("rfidresearchgroup/proxmark3", [firmware])
        self.assertEqual(result["testing_formulae"], f"{TOOLCHAIN},{firmware}")
        self.assertEqual(result["added_formulae"], firmware)
        self.assertNotIn("file://", calls)
        self.assertNotIn("install", calls)

    def test_changed_compiler_is_not_added_twice(self):
        firmware = "rfidresearchgroup/proxmark3/proxmark-firmware-rdv4"
        result, _ = self.plan("rfidresearchgroup/proxmark3", [TOOLCHAIN, firmware])
        self.assertEqual(result["testing_formulae"], f"{TOOLCHAIN},{firmware}")

    def test_existing_bottle_needs_no_bootstrap(self):
        for tap in ("rfidresearchgroup/proxmark3", "example/proxmark"):
            firmware = f"{tap}/proxmark-firmware-rdv4"
            result, calls = self.plan(tap, [firmware], bottled=True)
            self.assertEqual(result["testing_formulae"], firmware)
            self.assertNotIn("install", calls)

    def test_fork_bootstraps_external_compiler_but_does_not_replace_it(self):
        firmware = "example/proxmark/proxmark-firmware-rdv4"
        result, calls = self.plan("example/proxmark", ["example/proxmark/arm-none-eabi-gcc", firmware])
        self.assertEqual(result["testing_formulae"], firmware)
        self.assertEqual(result["added_formulae"], firmware)
        self.assertIn(f"install --build-bottle {TOOLCHAIN}", calls)
        self.assertIn("--root-url=file://", calls)
        self.assertIn(f"fetch --force-bottle {TOOLCHAIN}", calls)

    def test_fork_compiler_only_is_left_to_tap_syntax_checks(self):
        result, calls = self.plan("example/proxmark", ["example/proxmark/arm-none-eabi-gcc"])
        self.assertEqual(result["testing_formulae"], "")
        self.assertEqual(result["added_formulae"], "")
        self.assertEqual(calls, "")


if __name__ == "__main__":
    unittest.main()
