# Setup guide

## Supported setup

The installer targets 64-bit Windows 11. It downloads an embedded CPython 3.12.10 runtime, builds a copied repo-local `.venv`, installs pinned Python packages, downloads the pinned Prism llama.cpp CUDA runtime, and installs the default `bon2:27b-5gb` model under `.models/`.

Python 3.12.10 is pinned because it has the Windows embedded distribution this portable setup uses. It is not the latest security maintenance release of Python 3.12: [Python 3.12.15](https://www.python.org/downloads/release/python-31215/) is newer and source-only, while 3.12.10 was the final 3.12 release with binary installers. Review this pin before publishing or deploying Bon; do not describe it as the latest Python security release.

Plan for at least 9 GiB free on the repository drive for the minimum setup. The default GGUF is 5,946,648,928 bytes (about 5.54 GiB / 5.95 GB). The optional `bon2:27b-7gb` GGUF is about 7.21 GB more. Keep extra headroom for Python, CUDA runtime files, downloads, and temporary files. An NVIDIA GPU with 8 GiB VRAM is the tested target; do not assume every GPU can hold every context profile.

## Install

1. Clone or copy the repository to a writable local directory. Do not add `.models/`, `.venv/`, or `tools/` to Git; they are ignored by design.
2. In Windows Terminal or PowerShell, change to the repository root and run:

   ```powershell
   .\setup-repo.cmd
   ```

3. On a new setup, the installer shows the NVIDIA CUDA 12.4 EULA link before downloading the CUDA runtime bundle. Review the terms and type `ACCEPT` only if you agree. For an intentional non-interactive acceptance, run:

   ```powershell
   .\setup-repo.cmd -AcceptNvidiaCudaLicense
   ```

   The switch records your confirmation for the installer only; it is not legal advice and does not replace the upstream agreement. If you do not accept the terms, setup stops before downloading the runtime binaries.
4. Setup may add the repository directory to the current user's PATH. Open a new terminal, then run `bon`. To avoid PATH registration, use `.\setup-repo.cmd -SkipPathRegistration`.

The install is idempotent for the pinned versions: a later run verifies installed components and repairs missing files. It does not download `bon2:27b-7gb` unless requested.

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
| `.models/` | Downloaded model files and local runtime state | Ignored |
| `tools/.downloads/` | Verified download cache | Ignored |

## Troubleshooting

- If `bon` is not found after setup, open a new terminal or run `bon.cmd` from the repository directory.
- If setup reports less than 9 GiB free, free space on the drive containing the repository.
- If Python packages are missing, rerun `setup-repo.cmd`; Bon does not install or upgrade packages while serving prompts.
- If the CUDA runtime is not accepted, do not pass the acceptance switch. You may inspect the script and use the source without the bundled runtime, but the default GPU setup will not complete.
- If the model download is interrupted, rerun setup or repeat `bon pull bon2:27b-5gb`/`bon pull bon2:27b-7gb`; the model is downloaded from the pinned Hugging Face revision.
- If GPU memory is insufficient, close other GPU workloads, use `/slot 1`, or select a smaller context with `/context <tokens>`. These changes trade concurrency/context for memory.

For privacy and license boundaries, read [PRIVACY.md](PRIVACY.md) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
