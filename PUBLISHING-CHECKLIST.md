# GitHub publishing checklist

Repository files cannot enable GitHub account/repository settings by themselves. Before announcing a public release, review each item in the GitHub UI:

- [ ] Set a clear repository description and relevant topics; verify the repository name/URL and default branch.
- [ ] Review the MIT copyright holder and confirm that the named holder has rights to license every Bon-authored file and asset.
- [ ] Run the REUSE compliance checker against `REUSE.toml`; confirm it describes Bon-authored files only and is not presented as a third-party dependency license audit.
- [ ] Review [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md), the upstream model license, Prism release licensing, NVIDIA CUDA terms, and any applicable redistribution conditions. Obtain legal review if distributing binaries or model files.
- [ ] Run the setup and `bon` smoke test on a clean Windows 11 x64 machine; confirm downloaded versions, checksums where pinned, and model sizes match `tools/tool-lock.json`.
- [ ] Update [`RELEASE-NOTES.md`](RELEASE-NOTES.md), create a version/tag, and confirm the release files do not contain model weights, CUDA DLLs, tool archives, `.venv/`, `.models/`, credentials, or private logs.
- [ ] Require the CI workflow on pull requests and protect the default branch (review requirements, status checks, and no direct force pushes as appropriate).
- [ ] Enable Dependabot alerts/security updates and secret scanning/push protection where available; review CodeQL results.
- [ ] Enable private vulnerability reporting and verify the contact process in [`SECURITY.md`](SECURITY.md).
- [ ] Review the GitHub Community Profile and ensure issue forms, contribution guidance, code of conduct, license, citation metadata, and security policy appear correctly.
- [ ] Render `assets/bon-mark.svg` into an approved social-preview image and upload it; add repository links only after the final public URL is known.
- [ ] Re-check links, docs, license labels, package pins, and model/runtime hashes before release.

Relevant GitHub guidance: [repository best practices](https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories), [security quickstart](https://docs.github.com/en/code-security/getting-started/quickstart-for-securing-your-repository), [healthy contributions](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions), and [secure use of Actions](https://docs.github.com/en/actions/reference/security/secure-use).
