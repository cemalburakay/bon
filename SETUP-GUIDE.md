# Setup guide

## Supported setup

The installer targets 64-bit Windows 11. It downloads an embedded CPython 3.12.10 runtime, builds a copied repo-local `.venv`, installs pinned Python packages, downloads the pinned Prism llama.cpp CUDA runtime, and installs the default `bon2:27b-5gb` model under `.models/`. It extracts pinned Microsoft Visual C++ DLLs with a portable WiX tool and places them beside the inference executables. It does not run Microsoft's global installer, require system Python, or require administrator access. Windows' built-in PowerShell/.NET and cabinet expansion tools, a compatible NVIDIA driver, and network access remain prerequisites; setup does not install the GPU driver.

Python 3.12.10 is pinned because it has the Windows embedded distribution this portable setup uses. It is not the latest security maintenance release of Python 3.12: [Python 3.12.15](https://www.python.org/downloads/release/python-31215/) is newer and source-only, while 3.12.10 was the final 3.12 release with binary installers. Review this pin before publishing or deploying Bon; do not describe it as the latest Python security release.

Plan for at least 9 GiB free on the repository drive for the minimum setup. The default GGUF is 5,946,648,928 bytes (about 5.54 GiB / 5.95 GB). The optional `bon2:27b-7gb` GGUF is about 7.21 GB more. Keep extra headroom for Python, CUDA runtime files, downloads, and temporary files. An NVIDIA GPU with 8 GiB VRAM is the tested target; do not assume every GPU can hold every context profile.

## Install

1. Clone or copy the repository to a writable local directory. Do not add `.models/`, `.venv/`, or `tools/` to Git; they are ignored by design.

   ```powershell
   git clone --branch dev https://github.com/cemalburakay/bon.git
   cd bon
   ```
2. In Windows Terminal or PowerShell, change to the repository root and run:

   ```powershell
   .\setup-repo.cmd
   ```

3. Setup prints the component terms notice and completes without questions or acceptance switches. Review the following terms section **before** running it; there is no interactive cancellation checkpoint.
4. Setup may add the repository directory to the current user's PATH. Open a new terminal, then run `bon`. To avoid PATH registration, use `.\setup-repo.cmd -SkipPathRegistration`.

The install is idempotent for the pinned versions: a later run verifies installed components and repairs missing files. It does not download `bon2:27b-7gb` unless requested.

## Unattended installation and terms

By running this unattended installer, the installing operator acknowledges and accepts the applicable upstream terms. Do not run it if you do not accept them. The maintainer requested this non-interactive behavior; it is not a statement that the maintainer can consent on behalf of future users. Setup prints the notice on every run and never asks for `ACCEPT` or another response. It does not create a durable individual consent record, waive obligations, or certify redistribution rights.

- Bon original source: [MIT](LICENSE).
- NVIDIA CUDA 12.4 libraries: [NVIDIA EULA](https://docs.nvidia.com/cuda/archive/12.4.0/eula/index.html).
- Microsoft Visual C++ runtime 14.51.36247.0: [Microsoft runtime terms](https://aka.ms/VCRedistLicense) and [redistribution guidance](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170). App-local DLLs are not managed by the system-wide runtime updater; rerun/update Bon's pins when vendor security updates require it.
- WiX 3.14.1 portable extraction tool: [Microsoft Reciprocal License (MS-RL)](https://github.com/wixtoolset/wix3/blob/wix3141rtm/LICENSE.TXT). This archived tool is used only to extract the verified runtime package; it is not modified or bundled in the source release.
- Python, Python packages, and Bonsai models: their original license/notice files and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) apply. Bonsai's pinned license is Apache-2.0.

## Source-only rebuild

In a fresh clone, run the same `setup-repo.cmd`; no downloaded directory should be copied from another installation. For an existing checkout, inspect `git clean -ndX` before deliberately removing generated files with `git clean -fdX`. This **permanently deletes all ignored data**, including models, environments, caches, logs, and any user files placed in ignored paths; back up anything needed first. Do not use lowercase `-x`, which would also delete non-ignored untracked source files. The tracked `tools/tool-lock.json` and `.git` remain intact.

Setup and Bon default to repository-local download, virtualenv, and Hugging Face/Xet caches under `tools/.downloads/`. Explicit `HF_HOME`, `HF_HUB_CACHE`, or `HF_XET_CACHE` environment overrides remain supported. Python runs with bytecode writes disabled, and pip installs with `--no-compile`. A rebuild still depends on upstream download availability, the OS prerequisites, and compatible hardware; testing a source-only checkout does not certify all new PCs.

See the [source-only rebuild and GPU smoke report](CLEAN-INSTALL-REPORT.md) for the tested procedure, results, and limits.

## Optional model

After setup, fetch the larger variant when desired:

```powershell
bon pull bon2:27b-7gb
```

Alternatively, start the REPL with that model in one step:

```powershell
bon run bon2:27b-7gb
```

If it is not installed, `run` downloads the pinned model before starting the REPL.

Or from inside the REPL:

```text
/pull bon2:27b-7gb
```

The model file is saved to `.models/`, which is excluded from Git. Bon checks its pinned SHA-256 the first time it is used; later launches skip a full re-hash while file size and modification time are unchanged. Allow extra disk space and expect increased VRAM pressure.

Model pulls also save the pinned upstream `LICENSE` and `NOTICE.txt` under `.models/.licenses/<repository>/<revision>/`, with their own SHA-256 checks. Setup retains Python's original `tools/python/LICENSE.txt`, wheel license/notice files, and the runtime's complete credits in `tools/prism-cuda/THIRD-PARTY-LICENSES.txt`. These local files support attribution; do not treat the installed directory as a cleared redistribution bundle.

WiX's original `LICENSE.TXT` remains under `tools/wix/`. Microsoft's original package UI license reference and the package/terms URLs are retained under `tools/msvc-runtime/`. These references identify vendor terms; they are not a replacement license or permission to redistribute the downloaded DLLs under MIT.

## Portable layout

| Path | Purpose | Git status |
| --- | --- | --- |
| `bon.cmd` | Bon launcher | Tracked |
| `setup-repo.cmd` | Setup launcher | Tracked |
| `scripts/bon.py` | Application entrypoint | Tracked |
| `scripts/setup-repo.ps1` | Installer implementation | Tracked |
| `.instructions/` | Prompt/instruction documents | Tracked |
| `tools/tool-lock.json` | Version pins and source metadata | Tracked |
| `tools/python/` | Embedded base Python and bootstrap packages | Ignored |
| `.venv/` | Copied isolated Python environment | Ignored |
| `tools/prism-cuda/` | Downloaded Prism CUDA runtime | Ignored |
| `tools/msvc-runtime/` | Verified app-local Microsoft C++ DLLs | Ignored |
| `tools/wix/` | Portable runtime package extractor and upstream license | Ignored |
| `.models/` | Downloaded model files and local runtime state | Ignored |
| `tools/.downloads/` | Verified download cache | Ignored |

## Troubleshooting

- If `bon` is not found after setup, open a new terminal or run `bon.cmd` from the repository directory.
- If setup reports less than 9 GiB free, free space on the drive containing the repository.
- If Python packages are missing, rerun `setup-repo.cmd`; Bon does not install or upgrade packages while serving prompts.
- If you do not accept the component terms, do not run setup. There is no interactive terms prompt or acceptance switch.
- If the model download is interrupted, rerun setup or repeat `bon pull bon2:27b-5gb`/`bon pull bon2:27b-7gb`; the model is downloaded from the pinned Hugging Face revision.
- If GPU memory is insufficient, close other GPU workloads, use `/slot 1`, or select a smaller context with `/context <tokens>`. These changes trade concurrency/context for memory.

For privacy and license boundaries, read [PRIVACY.md](PRIVACY.md) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
