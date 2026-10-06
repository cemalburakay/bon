# Bon

Bon is a Windows-first command-line assistant for running a language model on your own computer. It wraps a pinned PrismML llama.cpp build, downloads the default Ternary-Bonsai 2 model into an ignored local directory, and gives you a small REPL with optional model-selected web search.

Bon is an independent community application. It is not made, endorsed, or supported by Prism ML, Hugging Face, Qwen, NVIDIA, DuckDuckGo, or the llama.cpp maintainers. “Ternary-Bonsai” and the model names below identify upstream components; they are not Bon products.

![Bon wordmark](assets/bon-mark.svg)

## What problem Bon solves

Bon began with a concrete personal goal: run a 27B ternary model locally on a Windows 11 laptop with an RTX 4060 Laptop GPU and 8 GiB VRAM, without requiring a system-wide Python installation or a long manual setup. The setup launcher provisions a pinned embedded Python runtime, an isolated repo-local environment, the pinned inference server, and the default model. The project then grew to include an optional second quantization, multiple local REPL clients, and model-selected web search. After setup, the simple path remains one command: `bon`.

It is useful for personal Q&A, prompt experiments, local demonstrations, and comparing two model quantizations without sending ordinary inference prompts to a hosted LLM API. The REPL defaults to one-shot turns, supports optional in-session history, and can ask the model to call a web-search tool when external or current information is useful.

## Honest value and limits

The practical value is convenience and control: a repeatable Windows setup, pinned local components, local inference after downloads, no per-request hosted-model API charge, and model choices behind short CLI tags. These are potential operational benefits, not measured savings or a claim of business ROI. Local hardware, electricity, disk space, maintenance, and initial downloads still have costs.

Bon is a personal-use CLI, not a hosted service, production platform, compliance product, or high-availability business system. It has no SLA, formal security certification, enterprise access control, audit trail, or guaranteed answer quality. Do not rely on it for medical, legal, financial, safety-critical, or other high-stakes decisions. It does not accept image/audio input, index files, or provide retrieval over a document library.

## Quick start

Requirements: 64-bit Windows 11, PowerShell, internet access for initial setup, and at least 9 GiB of free disk space. An NVIDIA GPU with 8 GiB VRAM is the tested target; other GPUs and CPU-only execution are not guaranteed to have the same performance or memory fit.

1. Run `setup-repo.cmd` from the repository directory.
2. Review the NVIDIA CUDA 12.4 terms shown by setup and type `ACCEPT` to continue. For a deliberate non-interactive acceptance, pass `-AcceptNvidiaCudaLicense`.
3. Open a new terminal if setup added the repository directory to your user PATH.
4. Run `bon` (or `bon.cmd` from this directory). To choose a model explicitly, use `bon run bon2:27b-5gb` or `bon run bon2:27b-7gb`.

The default `bon2:27b-5gb` GGUF is about 5.95 GB and is downloaded from Hugging Face during setup. The optional `bon2:27b-7gb` model is about 7.21 GB and is not downloaded automatically; `bon run bon2:27b-7gb` downloads it on first use. Details are in [SETUP-GUIDE.md](SETUP-GUIDE.md).

## What Bon does at runtime

- Runs the model server on `127.0.0.1`; normal inference is local after model and runtime downloads.
- Defaults to `bon2:27b-5gb`, deterministic sampling settings, a fast 34,816-token total context profile, two concurrent server slots, and history off.
- Uses a text-only chat interface. The underlying model repository also describes a vision tower, but Bon does not expose image input.
- Offers optional `bon2:27b-7gb` installation and model switching.
- Gives the model one `web_search` function. A model-selected search or explicit `/search` or `/web` command sends the extracted query to DuckDuckGo; it does not make all prompts local by magic. Search results are untrusted external data and are shown with source links.
- Keeps downloaded models in `.models/`; tools and Python packages live under ignored `tools/` and `.venv/`. None of those large runtime assets belong in Git.

Bon does not intentionally collect telemetry. Hugging Face receives download requests during setup/model pulls. DuckDuckGo receives a search query only when a search is invoked. See [PRIVACY.md](PRIVACY.md) and the [DuckDuckGo terms](https://duckduckgo.com/terms).

## Model tags

| Bon tag | Upstream file | Approx. size | Notes |
| --- | --- | ---: | --- |
| `bon2:27b-5gb` (default) | `Ternary-Bonsai-2-27B-PTQ1_0.gguf` | 5.95 GB | PTQ1_0, 1.75 bpw; f16 KV profile |
| `bon2:27b-7gb` (optional) | `Ternary-Bonsai-2-27B-PQ2_0.gguf` | 7.21 GB | PQ2_0, 2.13 bpw; q4_0 KV profile; greater VRAM pressure |

These files are from the pinned [Prism ML model repository](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/tree/6ed5e12bf84b7a63069882c91dd9e9218647d17b). Its model card identifies Apache-2.0 and names [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) as the base model. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md): Bon's MIT license does not relicense these model weights, NVIDIA libraries, or downloaded tools.

## Technical profile

The model-native context is 262,144 tokens, but that is not the default allocation and is not a promise that a given GPU can fit it. The normal profile allocates 34,816 total tokens across two slots (17,408 per slot); output is capped at 4,096 tokens, leaving up to 13,312 input tokens per slot in that profile. `/context max` requests the model-native profile and may fail or be much slower depending on GPU memory. Hardware, drivers, server build, parallel load, and prompt length affect real performance.

Sampling settings use temperature `0`, top-k `1`, and a fixed seed. This is deterministic configuration, not a guarantee of bit-identical output across different hardware, drivers, runtime builds, or concurrent workloads.

## Guides and project policies

- [Setup guide](SETUP-GUIDE.md)
- [User guide](USER-GUIDE.md)
- [Privacy and data flow](PRIVACY.md)
- [Changelog](CHANGELOG.md)
- [Draft release notes](RELEASE-NOTES.md)
- [Third-party notices](THIRD-PARTY-NOTICES.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Community code of conduct](CODE_OF_CONDUCT.md)
- [Publishing checklist](PUBLISHING-CHECKLIST.md)

The current CLI loads `.instructions/bon-general-assistant.md`. The additional math and English-tutor instruction files are retained as prompt templates; this build does not expose a command to switch between them.

## License

The original Bon source code and original project assets are offered under the MIT License in [LICENSE](LICENSE), with the copyright holder named there. That license applies only to Bon-authored material unless a file or notice says otherwise. Downloaded models, runtime binaries, CUDA libraries, Python, packages, and external services have their own terms; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

This repository's notices are informational, not legal advice, and do not guarantee that any particular distribution or use is lawful in every jurisdiction. Review upstream terms and obtain qualified legal advice before commercial distribution or other material use.
