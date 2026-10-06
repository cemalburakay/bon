# Contributing to Bon

Thanks for considering a contribution. Keep changes focused, explain the user problem they address, and avoid overstating model quality, privacy, security, or performance.

## Before opening an issue or pull request

- Search existing issues and the relevant guides first.
- For a bug report, include Windows version, GPU/VRAM, selected model tag, exact command, expected/actual behavior, and sanitized logs. Never attach prompts, tokens, personal data, or full model files unless you have checked them for sensitive content.
- For a change, describe the behavior, tests, setup impact, and any changed external downloads or licensing implications.

## Development checks

The runtime setup provisions Python 3.12.10 under `tools/python/` and `.venv/`. The app dependencies are pinned in `tools/tool-lock.json`. Do not add an unpinned runtime `pip install` or a second conflicting dependency lock without explaining the maintenance tradeoff.

Run the model-free tests from the repository root:

```powershell
.\.venv\Scripts\python.exe -B -m unittest discover -s tests -v
```

Parse-check the setup script:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\setup-repo.ps1).Path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) { throw ($errors | Out-String) }
```

GPU/model smoke tests require the downloaded model and compatible hardware, so state clearly when they were not run. Do not commit `.models/`, `.venv/`, or `tools/` downloads.

## Source, privacy, and license changes

- Keep application code, commands, messages, and build scripts in English. The tracked assistant instruction documents under `.instructions/` intentionally remain Turkish/English according to their teaching purpose.
- Update `tools/tool-lock.json`, `THIRD-PARTY-NOTICES.md`, and the relevant guides when changing a downloaded tool, model, runtime, or package.
- Before committing any vendored third-party file, add its actual copyright and SPDX license metadata (or a more-specific `REUSE.toml` entry) so the root Bon MIT fallback does not mislabel it.
- Do not copy upstream model logos, code, or license text without preserving attribution and applicable notices.
- Make any external network call, prompt exposure, or persistence change explicit in `PRIVACY.md` and the user guide.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Pull requests may be declined if ownership, license compatibility, or distribution rights are unclear.

## Pull request checklist

- [ ] The change is scoped and its user-visible impact is explained.
- [ ] Relevant model-free tests pass.
- [ ] Documentation and third-party notices are updated where needed.
- [ ] No secrets, model weights, tool archives, generated files, or private logs are included.
- [ ] Any third-party or licensing implications are identified for maintainer review.
