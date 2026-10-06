# Source-only rebuild and GPU smoke report

## Scope

Test date: 2026-10-06. The test used this existing Windows 11 x64 checkout with an NVIDIA GeForce RTX 4060 Laptop GPU (8,188 MiB reported VRAM), driver 596.49, and working internet access. All ignored installation assets were removed before the final run. Git metadata and tracked source were retained. This tests the source-only bootstrap path, not a fresh Windows installation or every possible developer machine.

## Clean-start evidence

1. Inspected `git clean -ndX`, resolved cleanup targets inside the repository, checked for linked top-level targets and running repository processes, and hashed every tracked source file.
2. Ran `git clean -fdX`. The first cleanup removed 2,284 ignored files, including earlier download probes. An initial bootstrap exposed a PowerShell security-module auto-loading failure; setup was corrected to load the built-in module by its explicit path.
3. After that correction, repeated the full cleanup to test the final installer without its newly created caches. This removed 2,324 ignored files. All **38 tracked files** retained the same SHA-256 across deletion; **zero ignored files** remained, and `tools/` contained only tracked `tool-lock.json`. `.venv/` and `.models/` were absent.
4. Ran plain `setup-repo.cmd`, without acceptance flags, preinstalled repository tools, or manual input. The final clean run began at **17:41:13 UTC** and completed at **17:42:57 UTC**, with exit code **0** in **104.38 seconds**.

The generated data was permanently removed and then downloaded/recreated. Do not use this cleanup procedure without backing up user data placed in ignored paths. Neither cleanup deleted `.git`, tracked source, scripts, or documents.

## Installed components and verification

| Check | Observed result |
| --- | --- |
| Embedded Python | 3.12.10 in `tools/python/` |
| Application Python | 3.12.10 in `.venv/Scripts/python.exe`; copied environment, no junction/reparse point |
| Python imports | All `sys.path` entries were repository-local; no system or AppData Python package path |
| Native prerequisites | Pinned, signed Microsoft runtime extracted with portable WiX; no global redistributable installer run |
| Default model | `bon2:27b-5gb`, 5,946,648,928 bytes; SHA-256 `53107f530aa52eb00912263ab1ee29bd199261c87cd7b4ad4ca1318c1fe33ee3` |
| Optional model | `bon2:27b-7gb` remained absent |
| Artifact integrity | 55 successful SHA-256 checks covering archives, wheels, model, notices, and both copies of the runtime DLLs; some wheel checks are repeated across environments |
| Package consistency | `pip check`: no broken requirements |
| Model-free tests | 15/15 passed after installation and again after the repeat setup |
| Bytecode policy | `sys.dont_write_bytecode` true; zero loose `.pyc`/`.pyo` files and zero `__pycache__` directories under source/test/Python environment paths |
| Default caches | Hugging Face/Xet under `tools/.downloads/huggingface/`; virtualenv app-data under `tools/.downloads/virtualenv/` |
| Retained notices | Python/wheel/WiX licenses, model `LICENSE`/`NOTICE.txt`, vendor runtime reference, and 16,845-byte Prism runtime credits |

The bytecode check excludes the upstream embedded standard-library ZIP, which legitimately contains vendor-supplied compiled modules. Explicit cache environment overrides remain supported.

## Actual REPL and GPU evidence

Started **`bon.cmd run bon2:27b-5gb`** and sent real prompts through the interactive terminal. Bon used port **8081**, safely avoiding the occupied default port, with the normal **34,816-token total context**, **two slots**, **4,096-token output cap**, and history off.

- `Merhaba` → `Merhaba! Size nasıl yardımcı olabilirim?`
- `İstanbul'un başkenti neresidir? Kısaca cevapla.` → `İstanbul’un başkenti yoktur; Türkiye’nin başkenti Ankara’dır. İstanbul ise ülkenin en büyük şehri ve önemli bir metropol merkezidir.`
- `/hist`, `/hist on`, `/clear`, `/hist off`, and `/pull bon2:27b-5gb` returned the expected status/success messages. `/exit` completed with exit code zero.

Live module inspection showed **MSVCP140.dll**, **VCRUNTIME140.dll**, **VCRUNTIME140_1.dll**, **cudart64_12.dll**, **cublas64_12.dll**, **cublasLt64_12.dll**, and **ggml-cuda.dll** loaded from **`tools/prism-cuda/`**, not a system-wide runtime directory. The server used the existing full-offload/KV-offload configuration. GPU utilization was sampled at **98–100%** during generation.

GPU-wide memory was **7,915 MiB** with the model loaded and **7,921 MiB (about 7.74 GiB)** during generation. This includes model, KV cache, compute buffers, and any other GPU allocations; it is **not** a measurement of model weights alone. After the REPL exited, no repository inference/Python processes remained, and the GPU memory reading returned to **0 MiB**.

## Small throughput measurement

An additional streaming chat request to the same running Bon server used Bon's normal instructions, deterministic settings, and available tool definition, with a **160-token test-only output cap**. It asked for four short advantages of a local Windows assistant. The reply hit this deliberate cap; it was not a complete answer-quality evaluation.

| Metric | Observed value |
| --- | ---: |
| Total prompt tokens | 528 |
| Cached prompt tokens | 491 |
| Newly evaluated prompt tokens | 37 |
| Output tokens | 160 |
| Time to first visible content | 1.339 s |
| End-to-end streaming request | 13.933 s |
| Server-reported generation speed | 12.625 tok/s |

These are one warmed-server observation, not a cold-start latency or a promise of 30 tok/s. The previous approximately 30 tok/s figure was **not reproduced** in this test. No changes to GPU power settings, driver configuration, or model sampling were made to inflate the result.

## Repeat installation and final state

Reran plain `setup-repo.cmd` after the smoke test: exit code **0**, **5.86 seconds**, no questions, and no optional model download. Cached verified artifacts were reused; pinned Python packages were reinstalled from local wheels. The generated installations remain present so `bon` is immediately usable; they remain ignored by Git.

The local branch was renamed from `main` to `dev`, preserving prior commits. Requested Git author/contact/username settings were written only to this checkout's `.git/config`; they are not installed for future clone users or applied globally. `github.user` is local metadata, not authentication. CI supports both `dev` and `main`. No GitHub repository was created, published, or pushed.

## Reproduce

From a fresh source checkout with the documented OS/driver prerequisites and accepted [upstream terms](SETUP-GUIDE.md#unattended-installation-and-terms):

```powershell
.\setup-repo.cmd
.\.venv\Scripts\python.exe -B -m pip check
.\.venv\Scripts\python.exe -B -m unittest discover -s tests -v
.\bon.cmd run bon2:27b-5gb
```

For an existing checkout, inspect the ignored-file deletion preview and back up anything needed before cleaning. Upstream availability, rate limits, antivirus policies, disk capacity, OS components, hardware/driver compatibility, and vendor terms remain external requirements. This successful source-only rebuild is evidence for the tested environment, not universal installation or legal clearance.
