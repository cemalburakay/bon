import fnmatch
import hashlib
import os
import runpy
import subprocess
import sys
import tempfile
import tomllib
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts" / "bon.py"


class BonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = runpy.run_path(str(SOURCE))

    def test_brand_default_and_model_tags(self):
        self.assertEqual(self.app["DEFAULT_MODEL_TAG"], "bon2:27b-5gb")
        self.assertEqual(set(self.app["MODEL_SPECS"]), {"bon2:27b-5gb", "bon2:27b-7gb"})
        self.assertTrue((ROOT / ".instructions" / "bon-general-assistant.md").is_file())
        self.assertIn("Bon uygulamasında", self.app["load_instructions"]())

    def test_fast_context_budget(self):
        self.assertEqual(self.app["context_for"]("bon2:27b-5gb"), 34_816)
        self.assertEqual(self.app["slot_context_for"]("bon2:27b-5gb", slots=2), 17_408)
        self.assertEqual(self.app["max_input_for"]("bon2:27b-5gb", slots=2), 13_312)

    def test_cli_help_uses_bon_brand(self):
        result = subprocess.run(
            [sys.executable, str(SOURCE), "--help"],
            check=True,
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
        self.assertIn("Usage: bon [run <bon2:27b-5gb|bon2:27b-7gb> | pull <bon2:27b-5gb|bon2:27b-7gb>]", result.stdout)

    def test_run_command_selects_requested_model(self):
        parse = self.app["parse_cli_args"]
        self.assertEqual(parse([]), ("run", "bon2:27b-5gb"))
        self.assertEqual(parse(["run", "BON2:27B-7GB"]), ("run", "bon2:27b-7gb"))
        self.assertEqual(parse(["pull", "bon2:27b-7gb"]), ("pull", "bon2:27b-7gb"))
        with self.assertRaises(SystemExit):
            parse(["run"])
        with self.assertRaises(SystemExit):
            parse(["run", "unknown"])

    def test_explicit_search_command(self):
        search = self.app["explicit_search_query"]
        self.assertEqual(search("/search current Python release"), "current Python release")
        self.assertEqual(search("/web weather in Istanbul"), "weather in Istanbul")
        self.assertIsNone(search("ordinary local question"))

    def test_web_search_tool_payload_and_untrusted_notice(self):
        payload = self.app["build_chat_payload"]([{"role": "user", "content": "hello"}], include_tools=True)
        self.assertEqual(payload["tools"][0]["function"]["name"], "web_search")
        self.assertEqual(payload["temperature"], 0.0)
        self.assertEqual(payload["top_k"], 1)
        notice = self.app["tool_result_content"]("query", [], None)
        self.assertIn("untrusted external data", notice)

    def test_tool_call_parser(self):
        parse = self.app["parse_web_search_call"]
        call = {"function": {"name": "web_search", "arguments": '{"query":"latest Python release"}'}}
        query, arguments, error = parse(call)
        self.assertEqual(query, "latest Python release")
        self.assertEqual(arguments["query"], query)
        self.assertIsNone(error)
        self.assertIsNotNone(parse({"function": {"name": "web_search", "arguments": "{}"}})[2])

    def test_server_binds_only_to_loopback(self):
        command = [str(part) for part in self.app["server_command"]("model.gguf", "bon2:27b-5gb", slots=1)]
        self.assertIn("127.0.0.1", command)
        self.assertIn("-ngl", command)

    def test_shared_server_model_must_match_requested_tag(self):
        ensure = self.app["ensure_shared_server_model"]
        ensure("bon2:27b-7gb", "bon2:27b-7gb")
        with self.assertRaises(RuntimeError):
            ensure("bon2:27b-5gb", "bon2:27b-7gb")
        with self.assertRaises(RuntimeError):
            ensure(None, "bon2:27b-7gb")

    def test_all_python_wheels_are_hash_pinned(self):
        packages = self.app["TOOL_LOCK"]["bootstrap_packages"] + self.app["TOOL_LOCK"]["python_packages"]
        for package in packages:
            self.assertTrue(package["wheel"])
            self.assertRegex(package["sha256"], r"^[0-9a-f]{64}$")

    def test_reuse_manifest_scopes_mit_to_bon_authored_files(self):
        manifest = tomllib.loads((ROOT / "REUSE.toml").read_text(encoding="utf-8"))
        self.assertEqual(manifest["version"], 1)
        self.assertEqual(manifest["annotations"][0]["precedence"], "closest")
        self.assertEqual(manifest["annotations"][0]["SPDX-License-Identifier"], "MIT")
        self.assertEqual(manifest["annotations"][0]["SPDX-FileCopyrightText"], "2026 Cemal Burak Ay")
        tracked = subprocess.run(
            ["git", "ls-files", "-z"], cwd=ROOT, check=True, capture_output=True
        ).stdout.decode().split("\0")
        patterns = manifest["annotations"][0]["path"]
        for relative_path in filter(None, tracked):
            if relative_path == "REUSE.toml" or relative_path == "LICENSE" or relative_path.startswith("LICENSES/"):
                continue
            self.assertTrue(any(fnmatch.fnmatchcase(relative_path, pattern) for pattern in patterns), relative_path)
        license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
        self.assertIn("MIT License", license_text)
        self.assertIn("Copyright (c) 2026 Cemal Burak Ay", license_text)

    def test_model_hash_verification_and_marker(self):
        payload = b"Bon model integrity test"
        expected = hashlib.sha256(payload).hexdigest()
        app_globals = self.app["verify_model_integrity"].__globals__
        original_work = app_globals["WORK"]
        original_marker_dir = app_globals["MODEL_INTEGRITY_DIR"]
        original_specs = app_globals["MODEL_SPECS"]
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            model_path = root / "sample.gguf"
            model_path.write_bytes(payload)
            app_globals["WORK"] = root
            app_globals["MODEL_INTEGRITY_DIR"] = root / ".integrity"
            app_globals["MODEL_SPECS"] = {"sample": {"sha256": expected}}
            try:
                self.app["verify_model_integrity"]("sample", model_path)
                self.assertTrue((root / ".integrity" / "sample.json").is_file())
                model_path.write_bytes(b"altered model bytes")
                with self.assertRaises(RuntimeError):
                    self.app["verify_model_integrity"]("sample", model_path)
            finally:
                app_globals["WORK"] = original_work
                app_globals["MODEL_INTEGRITY_DIR"] = original_marker_dir
                app_globals["MODEL_SPECS"] = original_specs

    def test_model_notices_are_retained_cached_and_hash_checked(self):
        payload = b"Upstream copyright and license notice\n"
        expected = hashlib.sha256(payload).hexdigest()
        ensure = self.app["ensure_model_notices"]
        corrupted_download = [False]

        def download(repo, filename, *, revision, local_dir, force_download):
            destination = Path(local_dir) / filename
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"corrupt notice" if corrupted_download[0] else payload)
            return str(destination)

        downloader = Mock(side_effect=download)
        fake_hub = types.ModuleType("huggingface_hub")
        fake_hub.hf_hub_download = downloader
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            overrides = {
                "WORK": root,
                "MODEL_SPECS": {"sample": {"repo": "publisher/model", "revision": "pinned-revision"}},
                "TOOL_LOCK": {"models": {"legal_files": [{"file": "NOTICE.txt", "sha256": expected}]}},
            }
            with patch.dict(ensure.__globals__, overrides), patch.dict(sys.modules, {"huggingface_hub": fake_hub}):
                ensure("sample")
                local_notice = root / ".licenses" / "publisher--model" / "pinned-revision" / "NOTICE.txt"
                self.assertEqual(local_notice.read_bytes(), payload)
                ensure("sample")
                self.assertEqual(downloader.call_count, 1)
                local_notice.write_bytes(b"tampered notice")
                corrupted_download[0] = True
                with self.assertRaisesRegex(RuntimeError, "legal-file SHA-256 mismatch"):
                    ensure("sample")
                self.assertTrue(downloader.call_args.kwargs["force_download"])


if __name__ == "__main__":
    unittest.main()
