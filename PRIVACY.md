# Privacy and data flow

Bon is a local CLI application, not a hosted inference service. It has no intentional telemetry or account system. “Local” does not mean every operation is offline: setup, model pulls, and optional web search contact external services.

| Activity | Data that leaves the computer | Destination |
| --- | --- | --- |
| Ordinary inference after setup | No prompt is intentionally sent to a hosted LLM API | Local llama.cpp-compatible server bound to `127.0.0.1` |
| Automatic `web_search` tool call | The model-produced search query | DuckDuckGo's public search endpoint |
| Explicit `/search` or `/web` command | The text after the command | DuckDuckGo's public search endpoint |
| Initial setup/model pulls | Requests and download metadata; model files are retrieved | Python.org, PyPI, GitHub Releases, Hugging Face, as applicable |

Search is automatic when the model chooses the available `web_search` tool. If you need to ensure no search query leaves the device, do not use `/search` or `/web`; note that automatic tool selection may still request a search. The model receives result text as untrusted external data, but external pages can still be wrong or misleading.

Bon does not intentionally save a transcript. History is off by default; `/hist on` retains prior turns only in that running REPL process, and `/clear` erases that in-memory history. The local inference runtime writes operational logs and state under `.models/`; avoid assuming those files contain no sensitive details. `.models/` is ignored by Git.

Use care with confidential or regulated information. Search queries may reveal information to DuckDuckGo, and setup traffic reveals downloads to the relevant providers. See [third-party terms](THIRD-PARTY-NOTICES.md).
