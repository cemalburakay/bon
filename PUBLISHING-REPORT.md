# GitHub source publication report

Publication date: 2026-10-06. Public repository: [cemalburakay/bon](https://github.com/cemalburakay/bon). Default branch: **`dev`**. This is source publication, not a tagged software release or a binary/model bundle.

## Execution log

- Located the installed GitHub CLI, version 2.83.1, and inspected the clean local `dev` branch and existing authenticated accounts.
- Accepted the operator-provided PAT through masked terminal input, verified its owner as `cemalburakay`, and ran `gh auth login --hostname github.com --git-protocol https --with-token`. Authentication was retained in the Windows credential store. No token was written into source files, commit messages, remote URLs, or this report.
- Preserved all previously registered accounts. Restored the previously active account after publishing. Added a repository-local Git credential helper that explicitly selects `cemalburakay` from the secure credential store; verified the returned credential's identity without printing it. Global Git credential settings were not replaced.
- Checked all 15 pre-publication commits: 112 distinct blob records, largest 45,313 bytes, zero forbidden generated/binary paths, and zero matches for the scanned GitHub/Hugging Face token and private-key patterns. This limited scan is not a complete secret/provenance audit.
- Reran the 15 model-free tests successfully. The earlier source-only installation and GPU smoke evidence remains in [CLEAN-INSTALL-REPORT.md](CLEAN-INSTALL-REPORT.md).
- Created the public repository with `gh repo create cemalburakay/bon --public --source=. --remote=origin`, with a short project description. No generated README/license template was added over the reviewed local files.
- Updated README/setup clone instructions and citation metadata with the actual public URL; committed those changes as **`200505f`**.
- Ran `git push --set-upstream origin dev` and `git push origin --tags`, retaining all existing commit history. No force push, history rewrite, deletion of remote data, or new version tag was performed.
- Set the remote default branch using `gh repo edit cemalburakay/bon --default-branch dev`.
- Verified public visibility, default branch `dev`, remote `HEAD` pointing to `refs/heads/dev`, and matching local/remote initial publication commit **`200505fc364904358459f4972bdc8631de63aa3e`**. The first published snapshot contained 39 tracked files and all 16 local commits at that point.
- Inspected the actual remote tree: no model weights, environments, tool installations, archives, credentials, or logs were present. The tracked `tools/tool-lock.json` remains included. GitHub recognized the original source license as **MIT**.
- Confirmed successful GitHub [CI](https://github.com/cemalburakay/bon/actions/runs/37509193311) and [CodeQL](https://github.com/cemalburakay/bon/actions/runs/37509193241) runs for the initial publication commit. Later commits generate their own workflow runs; inspect the [Actions page](https://github.com/cemalburakay/bon/actions) for current results.
- Confirmed GitHub's repository settings report **secret scanning enabled** and **push protection enabled**. No branch-protection or legal-clearance claims are made by this observation.
- Added this report to explicit REUSE metadata and the project guides, then committed/pushed the documentation follow-up to keep local and remote source synchronized.

## Scope and follow-up

- The public repository contains reviewed tracked source, scripts, documentation, original assets, and the complete Git history. Ignored installations are downloaded locally by setup; they were not uploaded.
- The public source preserves historical author/email metadata. New publication commits use the locally configured `Cemal Burak Ay` identity. No historical identities were silently rewritten.
- No GitHub Release, binary redistribution, model upload, new tag, or claim of universal installation/answer quality was made. Vendor terms and the unresolved matters in [LEGAL-REVIEW.md](LEGAL-REVIEW.md) continue to apply.
- The PAT was supplied in a conversation and has broad permissions. The operator should revoke/rotate it and prefer narrower permissions for future use. Rotation will require updating the saved `cemalburakay` credential; this task did not revoke credentials or disable any account.

## Access the published source

```powershell
git clone --branch dev https://github.com/cemalburakay/bon.git
cd bon
.\setup-repo.cmd
.\bon.cmd
```

Read the [setup terms](SETUP-GUIDE.md#unattended-installation-and-terms) before invoking the unattended installer. Publishing the repository does not itself grant rights to downloaded third-party artifacts or guarantee legal immunity.
