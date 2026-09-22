import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("stage-bottles.py")
SPEC = importlib.util.spec_from_file_location("stage_bottles", SCRIPT)
stage_bottles = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stage_bottles)


class StageBottleChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bottles = self.root / "bottles"
        self.bottles.mkdir()
        self.output = self.root / "upload"

    def archive(self, local="proxmark-client--4.1.arm64_tahoe.bottle.tar.gz", *,
                published="proxmark-client-4.1.arm64_tahoe.bottle.tar.gz", data=b"bottle"):
        (self.bottles / local).write_bytes(data)
        return {"local_filename": local, "filename": published,
                "sha256": hashlib.sha256(data).hexdigest()}

    def metadata(self, *tags, name="proxmark-client.bottle.json"):
        path = self.bottles / name
        path.write_text(json.dumps({"tap/proxmark-client": {
            "bottle": {"tags": dict(enumerate(tags))}}}))
        return path

    def rejected(self):
        with self.assertRaises((ValueError, KeyError, TypeError, OSError)):
            stage_bottles.stage(self.bottles, self.output)
        self.assertFalse(self.output.exists())

    def test_cli_stages_multiple_archives_with_release_filenames(self):
        tahoe = self.archive(data=b"tahoe")
        sequoia = self.archive("proxmark-client--4.1.arm64_sequoia.bottle.tar.gz",
                               published="proxmark-client-4.1.arm64_sequoia.bottle.tar.gz",
                               data=b"sequoia")
        self.metadata(tahoe, sequoia)
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.bottles), str(self.output)],
                                check=True, capture_output=True, text=True)
        self.assertIn("Staged 2 bottle archives", result.stdout)
        self.assertEqual({path.name for path in self.output.iterdir()},
                         {tahoe["filename"], sequoia["filename"]})
        self.assertEqual((self.output / tahoe["filename"]).read_bytes(), b"tahoe")
        self.assertEqual((self.output / sequoia["filename"]).read_bytes(), b"sequoia")

    def test_rejects_absolute_traversal_and_nested_names(self):
        original = self.archive()
        for field in ("local_filename", "filename"):
            for bad in ("/tmp/outside.tar.gz", "../outside.tar.gz", "sub/file.tar.gz",
                        "./file.tar.gz", "sub\\file.tar.gz", "file.tar.gz\n", "..", "",
                        "file.tar.gz#label", "bad\t.tar.gz", "-option.tar.gz", None):
                with self.subTest(field=field, name=bad):
                    self.metadata(dict(original, **{field: bad}))
                    self.rejected()

    def test_rejects_checksum_mismatch_before_copying_anything(self):
        good = self.archive()
        bad = self.archive("broken.tar.gz", published="broken.tar.gz", data=b"broken")
        bad["sha256"] = "0" * 64
        self.metadata(good, bad)
        self.rejected()

    def test_rejects_invalid_checksum(self):
        original = self.archive()
        for bad in ("", "abc", "z" * 64, None):
            with self.subTest(checksum=bad):
                self.metadata(dict(original, sha256=bad))
                self.rejected()

    def test_rejects_missing_archive(self):
        tag = self.archive()
        self.metadata(tag)
        (self.bottles / tag["local_filename"]).unlink()
        self.rejected()

    def test_rejects_archive_symlink_and_directory(self):
        tag = self.archive()
        self.metadata(tag)
        path = self.bottles / tag["local_filename"]
        path.unlink()
        outside = self.root / "outside.tar.gz"
        outside.write_bytes(b"bottle")
        path.symlink_to(outside)
        self.rejected()
        path.unlink()
        path.mkdir()
        self.rejected()

    def test_rejects_metadata_symlink(self):
        tag = self.archive()
        path = self.metadata(tag)
        outside = self.root / "metadata.json"
        path.rename(outside)
        path.symlink_to(outside)
        self.rejected()

    def test_deduplicates_identical_destinations_across_metadata(self):
        first = self.archive()
        second = self.archive("duplicate.tar.gz", published=first["filename"])
        self.metadata(first)
        self.metadata(second, name="duplicate.bottle.json")
        self.assertEqual(stage_bottles.stage(self.bottles, self.output), 1)
        self.assertEqual(len(list(self.output.iterdir())), 1)

    def test_rejects_conflicting_destinations_before_copying(self):
        first = self.archive()
        second = self.archive("different.tar.gz", published=first["filename"], data=b"different")
        self.metadata(first)
        self.metadata(second, name="different.bottle.json")
        self.rejected()

    def test_rejects_missing_empty_and_malformed_metadata(self):
        self.rejected()
        path = self.bottles / "empty.bottle.json"
        for content in ("{}", "[]", "invalid json", '{"formula":{"bottle":{"tags":{}}}}'):
            with self.subTest(content=content):
                path.write_text(content)
                self.rejected()

    def test_refuses_output_symlink_or_existing_contents(self):
        tag = self.archive()
        self.metadata(tag)
        existing = self.root / "existing"
        existing.mkdir()
        self.output.symlink_to(existing, target_is_directory=True)
        with self.assertRaises(ValueError):
            stage_bottles.stage(self.bottles, self.output)
        self.assertEqual(list(existing.iterdir()), [])
        self.output.unlink()
        self.output.mkdir()
        marker = self.output / "keep.txt"
        marker.write_text("keep")
        with self.assertRaises(ValueError):
            stage_bottles.stage(self.bottles, self.output)
        self.assertEqual(marker.read_text(), "keep")
        self.assertEqual(list(self.output.iterdir()), [marker])

    def test_accepts_an_existing_empty_output_directory(self):
        self.metadata(self.archive())
        self.output.mkdir()
        self.assertEqual(stage_bottles.stage(self.bottles, self.output), 1)


if __name__ == "__main__":
    unittest.main()
