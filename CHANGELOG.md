# Changelog

Notable changes to Bon are recorded here. This project has not made a tagged public release yet.

## Unreleased

### Added

- Portable Windows setup using pinned Python 3.12.10 embedded, an isolated `.venv`, and pinned inference/runtime downloads.
- Local CLI chat with `bon2:27b-5gb` as the default model and optional on-demand `bon2:27b-7gb` downloads.
- `bon run <model>` to start the REPL directly with a chosen model, downloading it if needed.
- SHA-256 verification for pinned Windows Python wheels and both model files.
- Model-selected `web_search` tool calls, explicit `/search` and `/web` commands, and source links.
- One-shot-by-default session behavior, opt-in history, configurable context and slot count, and deterministic sampling settings.
- GitHub community, security, contribution, citation, privacy, setup, user, and third-party licensing documentation.
- A REUSE/SPDX file-level licensing manifest for Bon-authored materials, separate from external component terms.

### Changed

- Standardized the product name, launch command, Python entrypoint, model tags, and instruction filenames as `Bon`/`bon`.
- Replaced the former shorthand model tags with `bon2:27b-5gb` and `bon2:27b-7gb` across the CLI and documentation.
- Moved all model downloads under the Git-ignored `.models/` directory.

### Known limitations

- Windows x64 is the supported setup path; other operating systems are not tested by the installer.
- The default context is deliberately smaller than the model-native maximum to reduce startup and VRAM pressure.
- Web search depends on DuckDuckGo's public web endpoint and may stop working if that service changes.
- Quality, speed, GPU fit, and answer determinism vary by hardware and runtime.
