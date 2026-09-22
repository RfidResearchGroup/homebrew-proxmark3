#!/usr/bin/env python3
"""Read-only checks around Homebrew's PR publication command."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess


BOTTLE_RUNNERS = ("macos-15", "macos-26")


def api(endpoint, *, paginate=False):
    args = ["gh", "api"]
    if paginate:
        args += ["--paginate", "--slurp"]
    return json.loads(subprocess.check_output([*args, endpoint], text=True))


def snapshot(repository, default_branch, pull_request, expected_head=""):
    if not re.fullmatch(r"[1-9][0-9]*", pull_request):
        raise ValueError("pull_request must be a positive PR number")
    pr = api(f"repos/{repository}/pulls/{pull_request}")
    if (pr["state"] != "open" or pr["base"]["ref"] != default_branch
            or pr["base"]["repo"]["full_name"].lower() != repository.lower()):
        raise ValueError("PR must be open and target this repository's default branch")
    head = pr["head"]["sha"]
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        raise ValueError("Invalid PR head SHA")
    if expected_head and head != expected_head.lower():
        raise ValueError("PR head changed or does not match the expected SHA")
    pages = api(
        f"repos/{repository}/actions/workflows/tests.yml/runs"
        f"?event=pull_request&head_sha={head}&per_page=100", paginate=True,
    )
    # GitHub can omit PR associations on fork runs. In that case the exact head
    # SHA and pull_request event remain the available association evidence.
    runs = [run for page in pages for run in page["workflow_runs"]
            if run["head_sha"] == head and run["event"] == "pull_request"
            and (not run.get("pull_requests")
                 or any(pr["number"] == int(pull_request) for pr in run["pull_requests"]))]
    if not runs:
        raise ValueError("No tests.yml run exists for this PR head")
    latest = max(runs, key=lambda run: (run["id"], run["run_attempt"]))
    if latest["status"] != "completed" or latest["conclusion"] != "success":
        raise ValueError("The latest tests.yml run must have completed successfully")
    artifact_pages = api(
        f"repos/{repository}/actions/runs/{latest['id']}/artifacts?per_page=100", paginate=True,
    )
    available = {artifact["name"] for page in artifact_pages for artifact in page["artifacts"]
                 if not artifact["expired"]}
    expected = {f"bottles_{runner}_{latest['id']}_{latest['run_attempt']}" for runner in BOTTLE_RUNNERS}
    missing = expected - available
    if missing:
        raise ValueError("Missing or expired bottle artifacts for the selected attempt: "
                         + ", ".join(sorted(missing)) + ". Use Re-run all jobs before publishing.")
    return {"repository": repository, "default_branch": default_branch,
            "pull_request": pull_request, "head_sha": head,
            "run_id": latest["id"], "run_attempt": latest["run_attempt"],
            "artifact_pattern": f"bottles_*_{latest['id']}_{latest['run_attempt']}"}


def verify(saved):
    current = snapshot(saved["repository"], saved["default_branch"],
                       saved["pull_request"], saved["head_sha"])
    if current != saved:
        raise ValueError("The selected CI run changed; start a new publication")


def release_tag(root):
    names = json.loads((root / "synced_versions_formulae.json").read_text())[0]
    sources = []
    for name in names:
        contents = (root / "Formula" / f"{name}.rb").read_text()
        url = re.search(r'^  url "([^"]+)"$', contents, re.MULTILINE)
        checksum = re.search(r'^  sha256 "([0-9a-f]{64})"$', contents, re.MULTILINE)
        if not url or not checksum:
            raise ValueError(f"Cannot read the stable source of {name}")
        sources.append((url[1], checksum[1]))
    if not sources or len(set(sources)) != 1:
        raise ValueError("Client and firmware sources are not synchronized")
    tag = re.fullmatch(
        r"https://github.com/RfidResearchGroup/proxmark3/archive/refs/tags/(v[0-9.]+)\.tar\.gz",
        sources[0][0],
    )
    if not tag:
        raise ValueError("Cannot identify the upstream release tag")
    return tag[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["snapshot", "verify", "tag"])
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    if args.action == "snapshot":
        saved = snapshot(os.environ["GITHUB_REPOSITORY"], os.environ["DEFAULT_BRANCH"],
                         os.environ["PULL_REQUEST"], os.environ.get("EXPECTED_HEAD_SHA", ""))
        args.path.write_text(json.dumps(saved))
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write(f"head_sha={saved['head_sha']}\n")
            output.write(f"artifact_pattern={saved['artifact_pattern']}\n")
    elif args.action == "verify":
        verify(json.loads(args.path.read_text()))
    else:
        print(release_tag(args.path))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error
