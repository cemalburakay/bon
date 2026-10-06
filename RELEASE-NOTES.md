# Release notes

## Draft for the first public release — not published

This repository is being prepared for its first public release. Do not treat this draft as a tagged or supported release. Before publishing, replace this heading with the actual version and date, rerun the setup and smoke tests on a clean Windows machine, and complete [PUBLISHING-CHECKLIST.md](PUBLISHING-CHECKLIST.md).

### Intended contents

- Bon, a Windows-first local inference REPL with portable, pinned setup.
- `bon run <model>` for direct startup with a selected model tag.
- The `bon2:27b-5gb` default Ternary-Bonsai 2 GGUF and an optional on-demand `bon2:27b-7gb` variant.
- Optional model-selected DuckDuckGo web search, with source links and an explicit external-query privacy notice.
- Local model serving, two-slot concurrency, default-off conversation history, and a fast context profile.
- Repository instructions, user/setup guides, open-source community files, tests, and third-party notices.

### Known limitations to disclose

- No SLA, formal security certification, hosted service, high-stakes accuracy guarantee, or measured business ROI.
- First setup needs internet and at least 9 GiB free disk space; the default model alone is about 5.95 GB.
- An 8 GiB GPU is close to full utilization with `bon2:27b-5gb`; other hardware may need a smaller context or CPU fallback.
- Search queries are sent to DuckDuckGo when search is invoked. Model/runtime and package downloads contact their upstream hosts.
- The NVIDIA CUDA runtime components have separate NVIDIA terms and are not included under Bon's MIT license.
- Publish the reviewed source archive; retain the upstream legal files when installing locally. Ownership and other open rights questions are recorded in [LEGAL-REVIEW.md](LEGAL-REVIEW.md).
