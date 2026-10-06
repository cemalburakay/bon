# User guide

## Start Bon

After setup, open a terminal and run:

```powershell
bon
```

The first run loads `bon2:27b-5gb`. A new prompt begins at `>>>`. Type a question and press Enter. Use `/exit` or Ctrl+C to leave.

Show command-line help without starting the model:

```powershell
bon --help
```

## When Bon is a good fit

Bon is aimed at individual local experimentation: trying prompts against the pinned model, running a small local demo, or handling occasional Q&A without sending ordinary turns to a hosted LLM API. If the computer and GPU are already available, it may reduce metered API usage for workloads that fit the model—but there is no cost study or guaranteed savings, and hardware, energy, downloads, and maintenance still cost money.

Bon is not a good fit for a multi-user production service, regulated or high-stakes decisions, guaranteed uptime/accuracy, central audit requirements, air-gapped first-time installation, or image/audio workflows. Treat those as unsupported unless you independently validate and secure a deployment.

## Models

- `bon2:27b-5gb` is the default and is installed by setup.
- `bon2:27b-7gb` is optional and downloads only when requested.
- `bon run bon2:27b-7gb` starts the REPL directly with that model, downloading it first if it is not installed.
- `bon run bon2:27b-5gb` explicitly starts the REPL with the default model.
- `bon pull bon2:27b-7gb` downloads the optional model from the command line.
- `/pull bon2:27b-7gb` downloads it inside the REPL.
- `/model` shows the active model; `/model bon2:27b-7gb` switches to it after it is installed.

Each shared local server runs one model tag. If another Bon REPL still owns a server for a different model, `bon run` fails with a clear mismatch instead of silently claiming the wrong model is active. Exit the other REPLs before starting a different tag.

The short tags identify upstream quantized model files. They do not mean Bon trained or owns those weights. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Conversation history

History is off by default, so each turn is a one-shot question. Turn in-session history on with `/hist on`; use `/clear` to clear it. `/hist off` disables history and clears the current session context. History exists in the running REPL process only and is not written as a conversation transcript by Bon.

The current build loads its default system prompt from `.instructions/bon-general-assistant.md`. The math and English-tutor files in that directory are templates, not selectable assistant modes.

## Search and privacy

The model may call `web_search` when it decides current or external information is needed. Bon then sends the extracted query to DuckDuckGo and displays returned source links. To explicitly search, enter `/search your query` or `/web your query`.

Search snippets are external, untrusted text. Verify important claims at their sources. Ordinary local inference sends prompts to the local server at `127.0.0.1`; when a search is invoked, the query leaves the computer. Initial model/runtime/package downloads also contact their upstream services. More detail: [PRIVACY.md](PRIVACY.md).

## Context, output, and concurrency

- `/context` displays the active context. `/context fast` returns to the responsive default; `/context max` requests the model's native maximum; `/context 12000` requests a specific total size.
- The model-native limit is 262,144 tokens, but actual usable input depends on slot count and the output allowance. The default is 34,816 total context split over two slots, or 17,408 per slot; in the default profile the input ceiling is 13,312 tokens and the output ceiling is 4,096.
- `/slot 1` reduces concurrency to one slot; `/slot 2` requests two. More slots divide the total context and can increase VRAM pressure.
- Eight GiB VRAM is nearly full while `bon2:27b-5gb` runs on the tested RTX 4060 Laptop GPU. Larger contexts, `bon2:27b-7gb`, other GPU use, or different hardware can fail to fit.

The server uses temperature zero, top-k one, and a fixed seed. These settings improve repeatability but cannot promise bit-identical output on all hardware and runtime combinations.

## Configuration environment variables

Bon reads optional `BON_`-prefixed environment variables for advanced tuning. Common ones are:

| Variable | Purpose |
| --- | --- |
| `BON_PORT` | Local server port (default 8080) |
| `BON_CONTEXT_MODE` | `fast` (default) or `max` |
| `BON_SERVER_CONTEXT_TOKENS` | Explicit context override, capped by model support |
| `BON_PARALLEL_SLOTS` | Default slot count |
| `BON_MAX_OUTPUT_TOKENS` | Output limit, at most 4,096 |
| `BON_KV_CACHE_TYPE` | Override the model's KV cache type |
| `BON_FLASH_ATTN` | Flash-attention runtime setting |
| `BON_THREADS`, `BON_BATCH_SIZE`, `BON_UBATCH_SIZE` | CPU and batch tuning |

Treat overrides as experiments. Unsupported values or VRAM requirements can prevent server startup. For all implementation defaults, see `scripts/bon.py` and `tools/tool-lock.json`.
