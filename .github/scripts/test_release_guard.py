import copy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import release_guard


HEAD = "a" * 40
REPOSITORY = "RfidResearchGroup/homebrew-proxmark3"
PR = {"state": "open", "base": {"ref": "master", "repo": {"full_name": REPOSITORY}},
      "head": {"sha": HEAD}}
RUN = {"id": 12, "run_attempt": 1, "status": "completed", "conclusion": "success",
       "head_sha": HEAD, "event": "pull_request", "pull_requests": [{"number": 42}]}


def artifacts_for(run=RUN):
    return [{"name": f"bottles_{runner}_{run['id']}_{run['run_attempt']}", "expired": False}
            for runner in release_guard.BOTTLE_RUNNERS]


class PublicationChecks(unittest.TestCase):
    def snapshot(self, pr=None, runs=None, expected="", artifacts=None):
        with patch.object(release_guard, "api", side_effect=[
                pr or PR, [{"workflow_runs": [RUN] if runs is None else runs}],
                [{"artifacts": artifacts_for() if artifacts is None else artifacts}]]) as api:
            result = release_guard.snapshot(REPOSITORY, "master", "42", expected)
            self.assertIn(f"head_sha={HEAD}", api.call_args_list[1].args[0])
            return result

    def test_successful_exact_head(self):
        saved = self.snapshot(expected=HEAD)
        self.assertEqual(saved["head_sha"], HEAD)
        self.assertEqual(saved["artifact_pattern"], "bottles_*_12_1")

    def test_closed_pr_and_wrong_destination(self):
        for field in ("state", "branch", "repository"):
            pr = copy.deepcopy(PR)
            if field == "state":
                pr["state"] = "closed"
            elif field == "branch":
                pr["base"]["ref"] = "main"
            else:
                pr["base"]["repo"]["full_name"] = "another/homebrew-tap"
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.snapshot(pr=pr)

    def test_expected_head_and_invalid_pr_number(self):
        with self.assertRaises(ValueError):
            self.snapshot(expected="b" * 40)
        with patch.object(release_guard, "api") as api, self.assertRaises(ValueError):
            release_guard.snapshot(REPOSITORY, "master", "42; echo unsafe")
        api.assert_not_called()

    def test_latest_failed_or_pending_run_blocks_older_success(self):
        for status, conclusion in [("completed", "failure"), ("in_progress", None),
                                   ("completed", "cancelled"), ("completed", "skipped")]:
            failed = dict(RUN, id=13, status=status, conclusion=conclusion)
            with self.subTest(conclusion=conclusion), self.assertRaises(ValueError):
                self.snapshot(runs=[failed, RUN])

    def test_missing_or_different_head_run_is_rejected(self):
        for runs in ([], [dict(RUN, head_sha="b" * 40)], [dict(RUN, event="push")],
                     [dict(RUN, pull_requests=[{"number": 43}])]):
            with self.subTest(runs=runs), self.assertRaises(ValueError):
                self.snapshot(runs=runs)

    def test_fork_run_without_pr_association_uses_exact_head(self):
        self.assertEqual(self.snapshot(runs=[dict(RUN, pull_requests=[])])["run_id"], RUN["id"])

    def test_verify_rejects_changed_head_or_new_ci_attempt(self):
        saved = self.snapshot()
        for pr, runs in [(dict(PR, head={"sha": "b" * 40}), [RUN]),
                         (PR, [dict(RUN, run_attempt=2)]),
                         (PR, [dict(RUN, id=13)])]:
            with patch.object(release_guard, "api", side_effect=[
                    pr, [{"workflow_runs": runs}], [{"artifacts": artifacts_for(runs[0])}]]):
                with self.assertRaises(ValueError):
                    release_guard.verify(saved)

    def test_verify_accepts_unchanged_success(self):
        saved = self.snapshot()
        with patch.object(release_guard, "api", side_effect=[
                PR, [{"workflow_runs": [RUN]}], [{"artifacts": artifacts_for()}]]):
            release_guard.verify(saved)

    def test_missing_platform_requires_rerunning_all_jobs(self):
        with self.assertRaisesRegex(ValueError, "Re-run all jobs"):
            self.snapshot(artifacts=artifacts_for()[:-1])

    def test_successful_partial_rerun_cannot_use_previous_attempt_artifacts(self):
        second_attempt = dict(RUN, run_attempt=2)
        artifacts = artifacts_for() + artifacts_for(second_attempt)[:1]
        with self.assertRaisesRegex(ValueError, "Re-run all jobs"):
            self.snapshot(runs=[second_attempt], artifacts=artifacts)

    def test_complete_rerun_keeps_the_artifact_pattern_on_that_attempt(self):
        second_attempt = dict(RUN, run_attempt=2)
        saved = self.snapshot(runs=[second_attempt], artifacts=artifacts_for() + artifacts_for(second_attempt))
        self.assertEqual(saved["artifact_pattern"], "bottles_*_12_2")

    def test_expired_artifact_blocks_snapshot_and_verify(self):
        saved = self.snapshot()
        artifacts = artifacts_for()
        artifacts[0]["expired"] = True
        with self.assertRaisesRegex(ValueError, "Re-run all jobs"):
            self.snapshot(artifacts=artifacts)
        with patch.object(release_guard, "api", side_effect=[
                PR, [{"workflow_runs": [RUN]}], [{"artifacts": artifacts}]]):
            with self.assertRaisesRegex(ValueError, "Re-run all jobs"):
                release_guard.verify(saved)

    def test_required_platforms_match_the_workflow_matrix(self):
        workflow = Path(__file__).parents[1] / "workflows/tests.yml"
        matrix = re.search(r"^\s+os:\s*\[([^\]]+)\]", workflow.read_text(), re.MULTILINE)
        self.assertIsNotNone(matrix)
        runners = tuple(value.strip().strip("'\"") for value in matrix[1].split(","))
        self.assertEqual(runners, release_guard.BOTTLE_RUNNERS)


def write_formulae(root):
    (root / "Formula").mkdir()
    names = ["proxmark-client", "proxmark-firmware-generic"]
    (root / "synced_versions_formulae.json").write_text(json.dumps([names]))
    for name in names:
        (root / "Formula" / f"{name}.rb").write_text(
            '  url "https://github.com/RfidResearchGroup/proxmark3/archive/refs/tags/v4.23346.tar.gz"\n'
            f'  sha256 "{"c" * 64}"\n')


class TagChecks(unittest.TestCase):
    def test_source_versions_and_checksums_must_agree(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_formulae(root)
            self.assertEqual(release_guard.release_tag(root), "v4.23346")
            formula = root / "Formula/proxmark-firmware-generic.rb"
            original = formula.read_text()
            for contents in (original.replace("v4.23346", "v4.23347"),
                             original.replace("c" * 64, "d" * 64)):
                formula.write_text(contents)
                with self.assertRaises(ValueError):
                    release_guard.release_tag(root)

    def test_local_tag_is_pinned_idempotent_and_never_moved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "checkout"
            root.mkdir()
            remote = Path(directory) / "remote.git"

            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True,
                                               stderr=subprocess.DEVNULL).strip()

            git("init", "--bare", str(remote))
            git("init")
            git("config", "user.name", "Offline test")
            git("config", "user.email", "test@example.invalid")
            git("remote", "add", "origin", str(remote))
            write_formulae(root)
            (root / ".github/scripts").mkdir(parents=True)
            shutil.copy(Path(__file__).with_name("release_guard.py"), root / ".github/scripts")
            git("add", ".")
            git("commit", "-m", "Fixture")
            first = git("rev-parse", "HEAD")

            def tag(sha):
                return subprocess.run(["bash", str(Path(__file__).with_name("tag-release.sh").resolve())],
                                      cwd=root, env=dict(os.environ, RELEASE_SHA=sha),
                                      capture_output=True, text=True)

            self.assertEqual(tag(first).returncode, 0)
            self.assertEqual(tag(first).returncode, 0)
            git("commit", "--allow-empty", "-m", "Another commit with the same version")
            self.assertNotEqual(tag(git("rev-parse", "HEAD")).returncode, 0)
            self.assertEqual(git("--git-dir", str(remote), "rev-parse", "v4.23346^{}"), first)
            self.assertNotEqual(tag(first).returncode, 0)  # Checkout must match the supplied SHA.


if __name__ == "__main__":
    unittest.main()
