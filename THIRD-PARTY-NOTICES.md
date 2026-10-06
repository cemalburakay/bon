# Third-party notices

Bon downloads and uses third-party software and model files. The table below records the versions currently pinned in [`tools/tool-lock.json`](tools/tool-lock.json). These components are fetched at setup/runtime; they are not committed into this Git repository. Upstream license files and terms control each component. This notice is a practical inventory, not a legal opinion or a guarantee that redistribution is permitted.

## Runtime and model components

| Component | Version/source | License or terms | Attribution/source |
| --- | --- | --- | --- |
| CPython embedded distribution | 3.12.10, Windows x64 | PSF-2.0 | [Python license](https://docs.python.org/3/license.html), [official release](https://www.python.org/downloads/release/python-31210/) |
| PrismML llama.cpp fork | `prism-b10709-9a9394a` | MIT for the source repository; release assets may include other components | [Pinned source license](https://github.com/PrismML-Eng/llama.cpp/blob/prism/LICENSE), [release](https://github.com/PrismML-Eng/llama.cpp/releases/tag/prism-b10709-9a9394a) |
| cpp-httplib, linked into the pinned Windows runtime | As listed by `llama.exe licenses` | MIT | [yhirose/cpp-httplib](https://github.com/yhirose/cpp-httplib) |
| BoringSSL, linked into the pinned Windows runtime | As listed by `llama.exe licenses` | Apache-2.0 | [BoringSSL license](https://boringssl.googlesource.com/boringssl/+/refs/heads/main/LICENSE) |
| Go support code bundled with BoringSSL | As listed by `llama.exe licenses` | BSD-style license | [Go license](https://go.dev/LICENSE) |
| nlohmann/json header (`jsonhpp`) | As listed by `llama.exe licenses` | MIT | [nlohmann/json](https://github.com/nlohmann/json) |
| NVIDIA CUDA runtime libraries in the Prism CUDA archive | CUDA 12.4 (`cudart64_12.dll`, `cublas64_12.dll`, `cublasLt64_12.dll`) | NVIDIA CUDA EULA; separate from MIT | [CUDA 12.4 EULA](https://docs.nvidia.com/cuda/archive/12.4.0/eula/index.html) |
| Ternary-Bonsai 2 27B GGUF | Prism ML repo, pinned revision `6ed5e12bf84b7a63069882c91dd9e9218647d17b` | Apache-2.0 as declared in the model card | [Pinned model card and license declaration](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/tree/6ed5e12bf84b7a63069882c91dd9e9218647d17b) |
| Qwen3.8-27B base model identified by the Bonsai card | Upstream base model (Bon does not download it) | Apache-2.0 as declared by the upstream model card | [Qwen model card and files](https://huggingface.co/Qwen/Qwen3.8-27B) |

Bon itself downloads only the listed Bonsai GGUF files, not the Qwen base weights. The model's own card and license are authoritative for the model files and any conditions that apply to use or redistribution.

## Python packages

License identifiers below are taken from the pinned distributions' package metadata; the linked upstream project is the place to review the full license text and notices. The `filelock` package is used in both the bootstrap and application environments.

| Package | Pinned version | SPDX license expression | Upstream project |
| --- | ---: | --- | --- |
| anyio | 4.15.1 | MIT | [agronholm/anyio](https://github.com/agronholm/anyio) |
| certifi | 2026.7.22 | MPL-2.0 | [certifi/python-certifi](https://github.com/certifi/python-certifi) |
| click | 8.5.0 | BSD-3-Clause | [pallets/click](https://github.com/pallets/click) |
| colorama | 0.4.6 | BSD-3-Clause | [tartley/colorama](https://github.com/tartley/colorama) |
| distlib | 0.4.3 | PSF-2.0 | [pypa/distlib](https://github.com/pypa/distlib) |
| filelock | 4.0.12 | MIT | [tox-dev/py-filelock](https://github.com/tox-dev/py-filelock) |
| fsspec | 2026.9.0 | BSD-3-Clause | [fsspec/filesystem_spec](https://github.com/fsspec/filesystem_spec) |
| h11 | 0.16.0 | MIT | [python-hyper/h11](https://github.com/python-hyper/h11) |
| hf-xet | 1.6.0 | Apache-2.0 | [huggingface/xet-core](https://github.com/huggingface/xet-core) |
| httpcore | 1.0.9 | BSD-3-Clause | [encode/httpcore](https://github.com/encode/httpcore) |
| httpx | 0.28.1 | BSD-3-Clause | [encode/httpx](https://github.com/encode/httpx) |
| huggingface_hub | 1.32.0 | Apache-2.0 | [huggingface/huggingface_hub](https://github.com/huggingface/huggingface_hub) |
| idna | 3.20 | BSD-3-Clause | [kjd/idna](https://github.com/kjd/idna) |
| packaging | 26.3 | Apache-2.0 OR BSD-2-Clause | [pypa/packaging](https://github.com/pypa/packaging) |
| pip | 26.2.1 | MIT | [pypa/pip](https://github.com/pypa/pip) |
| platformdirs | 4.12.3 | MIT | [tox-dev/platformdirs](https://github.com/tox-dev/platformdirs) |
| PyYAML | 6.0.3 | MIT | [yaml/pyyaml](https://github.com/yaml/pyyaml) |
| python-discovery | 1.6.1 | MIT | [tox-dev/python-discovery](https://github.com/tox-dev/python-discovery) |
| tqdm | 4.70.1 | MPL-2.0 AND MIT | [tqdm/tqdm](https://github.com/tqdm/tqdm) |
| typing-extensions | 4.16.0 | PSF-2.0 | [python/typing_extensions](https://github.com/python/typing_extensions) |
| virtualenv | 21.14.5 | MIT | [pypa/virtualenv](https://github.com/pypa/virtualenv) |

The Windows x64 / CPython 3.12 bootstrap and application wheels are pinned by filename and SHA-256 in `tools/tool-lock.json`. Setup checks the requested wheel against the versioned PyPI metadata, verifies its downloaded bytes, and installs the local wheel with package-index access disabled. The two model files are pinned by Hugging Face revision, expected size, and LFS SHA-256; Bon verifies the digest on first use and reuses a local integrity marker while the file's size and modification time remain unchanged. Review transitive/native package notices and upstream releases before relying on this inventory as a full SBOM.

The pinned Windows Prism release's `llama.exe licenses` command was inspected for this notice and listed llama.cpp, cpp-httplib, BoringSSL, Go support code, and jsonhpp. Re-inspect that command and Prism's source `licenses/` directory whenever the runtime release changes. The CUDA archive is a separate asset and its NVIDIA terms do not appear in that command.

## Web search service

Bon's optional search feature sends a query to DuckDuckGo's public search endpoint. DuckDuckGo is an external service, not a component licensed by Bon. Use is subject to [DuckDuckGo's terms](https://duckduckgo.com/terms) and [privacy policy](https://duckduckgo.com/privacy).

## GitHub Actions used for repository checks

| Action | Pinned release | License/source |
| --- | --- | --- |
| actions/checkout | v7.0.1, commit `3d3c42e5aac5ba805825da76410c181273ba90b1` | [MIT](https://github.com/actions/checkout) |
| actions/setup-python | v7.0.0, commit `5fda3b95a4ea91299a34e894583c3862153e4b97` | [MIT](https://github.com/actions/setup-python) |
| github/codeql-action | v4.38.2, commit `88585263c0627ee42c0e1c5143a112c8d6f4aa18` | [MIT](https://github.com/github/codeql-action) |

These actions run in GitHub-hosted CI; they are not included in Bon's end-user installer.

## No blanket relicensing

The root [MIT license](LICENSE) applies to original Bon source and assets only. It does not grant rights to third-party model weights, CUDA libraries, runtime binaries, Python packages, project names, or marks. In particular, do not re-upload the downloaded model or Prism/NVIDIA binaries as if they were MIT-licensed Bon artifacts. Check each upstream license and applicable terms before redistribution.
