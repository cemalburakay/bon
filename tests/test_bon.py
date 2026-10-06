import os
import runpy
import subprocess
import sys
import unittest
from pathlib import Path


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


if __name__ == "__main__":
    unittest.main()
