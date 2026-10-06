# Repository licensing review

Review date: 2026-10-06. Baseline: commit `e50fbd5`, followed by the changes described below. This is a technical evidence review for source publication, not an attorney's opinion, title certification, or assurance against claims. No governing jurisdiction, employer agreement, signed rights assignment, or trademark clearance was supplied.

## Publication scope

The reviewed publication consists of Git-tracked Bon source, configuration, documentation, and the SVG mark. Models, Python installations, wheel archives, CUDA DLLs, local environments, and logs are excluded. A ZIP of the working directory can include ignored downloads; produce source archives with `git archive` instead. A later binary/model bundle, paid service, or hosted deployment needs its own review.

## Findings and corrections

| Finding | Evidence and action |
| --- | --- |
| A single MIT label did not describe the full embedded Python distribution | Inspected the pinned archive's installed `LICENSE.txt` and DLL inventory. Added historical/bundled notices and the Microsoft Windows redistribution conditions to the inventory. |
| Model-card metadata was insufficient notice preservation | Retrieved the actual `LICENSE` and `NOTICE.txt` at the pinned model revision. Added their hashes to the lock and retention beside downloaded models. |
| Runtime credits were only embedded in an executable | Inspected `llama.exe licenses`; setup now saves its complete output as a readable local notice file. |
| CodeQL action and CLI licenses were conflated | Documented the CLI's separate GitHub terms and restricted the default workflow to public repositories. |
| Wildcard MIT metadata could label newly imported files automatically | Replaced global REUSE patterns with an explicit reviewed file list; file-specific declarations retain precedence. New files need a provenance/licensing decision. |
| Warranty wording could be mistaken for complete immunity | Kept the standard MIT text unchanged and clarified that notices do not eliminate mandatory liabilities or transfer the maintainer's obligations. |

The pinned model notice identifies Prism ML, Inc. and credits Alibaba Cloud/Qwen3.8-27B. The source records are linked in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Package-level SPDX declarations were checked against 20 distinct locked bootstrap/application wheels and their packaged license files. These are primary declarations; native/Rust dependencies and nested seed wheels are not exhaustively mapped here.

## Git history evidence

At the baseline, all reachable Git history contained 78 distinct blob records; the largest was 43,944 bytes. The history inventory found no model weights, native binaries, wheel/ZIP archives, runtime directories, or Python bytecode paths. A targeted text scan found no private-key headers or common GitHub/Hugging Face token patterns. These checks are not a complete secret or provenance audit.

The history contains one author-name identity and one author email. The author name differs from the selected copyright holder, Cemal Burak Ay. Git metadata neither proves nor disproves copyright ownership. Confirm the holder's authority and whether the commit identity/email should become public before publishing history. The review does not print the email here and does not rewrite history.

## Matters that documents cannot resolve

- Confirm ownership or permission for the starting code, subsequent contributions, prompts, and mark, including any employer or coauthor rights. AI assistance and a copyright header are not independent proof of clean provenance.
- Assess the Bon name/mark, patents, and other third-party rights in the intended countries and use cases; no trademark search or patent clearance is asserted.
- Review the applicable jurisdiction and any mandatory consumer, product, data-protection, export, or other obligations. A free public repository and an MIT disclaimer are not universal exemptions.
- Retain complete upstream licenses and notices if distributing external artifacts. Microsoft/NVIDIA conditions, MPL-covered files, and nested/native dependencies require artifact-specific review. Installer acknowledgement is not redistribution clearance.
- Model weight licensing does not establish exclusivity or non-infringement of generated output or the training data. Search-service terms and lawful handling of personal/confidential queries also remain applicable.

These questions should be answered by the maintainer and qualified counsel for the actual release. Until then, this review supports documented source publication preparation, not a declaration that publication is legally risk-free.

## Evidence sources and ongoing checks

For this proposed change, 13 model-free tests passed, including notice checksum/cache behavior. REUSE 6.2.0 reported 35/35 covered files with no missing, unused, or invalid licenses. The installer completed with exit code zero; retained model legal files matched their pinned hashes, and the runtime notice output contained 16,845 bytes. PowerShell/TOML/JSON/YAML and local document links were checked. A proposed Git source archive contained 38 files, all required license/review documents, and no forbidden runtime/model/archive/log paths. The optional 7 GB weights were not downloaded for this review.

The authoritative source records include the [MIT text](https://spdx.org/licenses/MIT), [Apache-2.0 conditions](https://www.apache.org/licenses/LICENSE-2.0), [Python license history](https://docs.python.org/3.12/license.html) and the pinned archive's `LICENSE.txt`, [NVIDIA CUDA terms](https://docs.nvidia.com/cuda/archive/12.4.0/eula/index.html), [CodeQL CLI terms](https://github.com/github/codeql-cli-binaries/blob/main/LICENSE.md), and [REUSE's scope](https://reuse.software/faq/). Versioned model records and package sources are in the third-party inventory.

Run the REUSE checker, model-notice integrity checks, source-archive/history inventory, and document-link checks again when release contents or pins change. Passing a metadata linter or matching a checksum establishes technical consistency, not title, license compatibility, or immunity from liability.
