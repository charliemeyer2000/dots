---
name: axle
description: "Use the AXLE (Axiom Lean Engine) API to verify, check, analyze, and transform Lean 4 theorem proofs via the axiom-axle Python SDK, CLI, or HTTP API. Trigger this skill whenever the user works with Lean 4 formal proofs, asks to verify/check theorems, mentions AXLE/axle, wants to manipulate Lean code (simplify, repair, extract, merge, rename, disprove), or needs to validate candidate proofs against formal statements. Also trigger when the user mentions sorry, proof verification, Mathlib, or formal mathematics tooling."
---

# AXLE -- Axiom Lean Engine

AXLE is a SaaS API for Lean 4 proof verification and manipulation. It provides 14 tools for checking, verifying, transforming, and analyzing Lean code -- all without needing a local Lean installation.

Docs: https://axle.axiommath.ai/v1/docs/
GitHub: https://github.com/AxiomMath/axiom-lean-engine
MCP server: `axiom-axle-mcp` on PyPI (for agent tool-use)

## Setup

- **Package**: `axiom-axle` (`uv add axiom-axle` or `pip install axiom-axle`)
- **Import**: `from axle import AxleClient`
- **Auth**: Set `AXLE_API_KEY` env var (get one at https://axle.axiommath.ai/app/console). Without a key, requests are limited to 10 concurrent; with a key, 20.
- **Run scripts**: `uv run python3 script.py` from the project root

## Core Pattern

All AXLE calls are async. Use this pattern:

```python
import asyncio
from axle import AxleClient

async def main():
    async with AxleClient() as client:
        result = await client.check(
            content="import Mathlib\ntheorem foo : 1 + 1 = 2 := by decide",
            environment="lean-4.28.0",
        )
        print(f"Valid: {result.okay}")
        if not result.okay:
            for e in result.lean_messages.errors:
                print(f"  {e}")

asyncio.run(main())
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AXLE_API_KEY` | -- | API key for auth |
| `AXLE_API_URL` | `https://axle.axiommath.ai` | API server URL |
| `AXLE_TIMEOUT_SECONDS` | `1800` | Retry window (seconds) when service is temporarily unavailable |
| `AXLE_MAX_CONCURRENCY` | `20` | Max concurrent requests from client |

### Constructor

```python
client = AxleClient(
    api_key="...",               # falls back to AXLE_API_KEY
    url="...",                   # falls back to AXLE_API_URL
    base_timeout_seconds=600,    # falls back to AXLE_TIMEOUT_SECONDS
    max_concurrency=50,          # falls back to AXLE_MAX_CONCURRENCY
)
```

## Lean Environments

The `environment` parameter is required for every tool call. Use `"lean-4.28.0"` as the default (latest Lean + Mathlib). For benchmarking against DeepSeek/Goedel papers, use `"lean-4.9.0"`.

```python
envs = await client.environments()
for env in envs:
    print(f"{env.name}: {env.description}")
```

Each environment has: `name`, `lean_toolchain`, `repo_url`, `revision`, `subdir`, `imports`, `description`.

Special environments exist for specific projects (e.g., `pnt-4.26.0` for Prime Number Theorem).

## Tools Quick Reference

| Task | Tool | Key params |
|------|------|-----------|
| Check if Lean code compiles | `check` | `content`, `environment` |
| Verify proof against a statement | `verify_proof` | `formal_statement`, `content`, `environment` |
| Split file into individual theorems | `extract_theorems` | `content`, `environment` |
| Strip proofs -> sorry | `theorem2sorry` | `content`, `names`/`indices` |
| Fix broken proofs | `repair_proofs` | `content`, `terminal_tactics` |
| Simplify verbose proofs | `simplify_theorems` | `content`, `simplifications` |
| Try to disprove a claim | `disprove` | `content`, `names` |
| Extract `have` -> standalone lemmas | `have2lemma` | `content`, `include_have_body` |
| Replace `have` bodies -> sorry | `have2sorry` | `content`, `names` |
| Extract `sorry` -> standalone lemmas | `sorry2lemma` | `content`, `extract_sorries` |
| Merge multiple Lean files | `merge` | `documents` (list[str]) |
| Rename declarations | `rename` | `content`, `declarations` (dict) |
| Convert theorem<->lemma keywords | `theorem2lemma` | `content`, `target` |
| Standardize formatting | `normalize` | `content`, `normalizations` |

For detailed parameter docs, see `references/tools-reference.md`.

## Common Workflows

### 1. Verify a candidate proof against a formal statement

The formal statement should contain `sorry` where the proof goes. The content is the candidate proof. Primary tool for proof validation in benchmarks.

```python
result = await client.verify_proof(
    formal_statement="import Mathlib\ntheorem foo : 1 = 1 := by sorry",
    content="import Mathlib\ntheorem foo : 1 = 1 := rfl",
    environment="lean-4.28.0",
)
# result.okay -> True if proof is valid
# result.tool_messages.errors -> why it failed
# result.failed_declarations -> which declarations failed
```

Use `permitted_sorries=["helper_name"]` if the proof uses sorry'd helper lemmas intentionally.

To allow `native_decide`, include `permitted_sorries=["Lean.trustCompiler", "Lean.ofReduceBool", "Lean.ofReduceNat"]`.

**Security note**: `verify_proof` trusts the Lean environment. Crafted metaprogramming can exploit this. For adversarial settings, also use [lean4checker](https://github.com/leanprover/lean4checker), [Comparator](https://github.com/leanprover/comparator), or [SafeVerify](https://github.com/GasStationManager/SafeVerify).

### 2. Batch-verify proofs from a dataset

```python
import json
results = []
async with AxleClient() as client:
    for line in open("dataset/test.jsonl"):
        item = json.loads(line)
        statement = item["formal_statement"] + "sorry"
        proof = item.get("proof", statement)
        r = await client.verify_proof(
            formal_statement=statement,
            content=proof,
            environment="lean-4.9.0",  # match benchmark version
        )
        results.append({"name": item["name"], "valid": r.okay})
```

### 3. Extract theorems and analyze dependencies

```python
result = await client.extract_theorems(
    content=open("solution.lean").read(),
    environment="lean-4.28.0",
)
for name, doc in result.documents.items():
    print(f"{name}: sorry={doc.is_sorry}, deps={doc.local_value_dependencies}")
    print(f"  proof_length={doc.proof_length}, tactics={doc.tactic_counts}")
```

See `references/tools-reference.md` for full Document field list (dependencies, positions, tactics, etc.).

### 4. Create problem templates from solutions

```python
result = await client.theorem2sorry(
    content=solution_code,
    environment="lean-4.28.0",
)
# result.content has all proofs replaced with sorry

# Or strip specific theorems by name
result = await client.theorem2sorry(
    content=solution_code,
    names=["main_theorem"],
    environment="lean-4.28.0",
)
```

### 5. Repair broken proofs

```python
result = await client.repair_proofs(
    content=broken_code,
    environment="lean-4.28.0",
    terminal_tactics=["decide", "simp", "omega", "aesop", "grind"],
)
# result.okay -> True if repair succeeded
# result.repair_stats -> {"apply_terminal_tactics": 2, ...}
```

Available repairs: `remove_extraneous_tactics`, `apply_terminal_tactics`, `replace_unsafe_tactics`.

### 6. Disprove false conjectures

```python
result = await client.disprove(
    content="import Mathlib\ntheorem false_claim : 2 = 3 := by sorry",
    environment="lean-4.28.0",
)
# result.disproved_theorems -> ["false_claim"]
# result.results -> per-theorem outcome strings
```

Powered by Plausible (counterexample generation). Useful for sanity-checking formal statements.

### 7. Simplify verbose proofs

```python
result = await client.simplify_theorems(
    content=verbose_code,
    environment="lean-4.28.0",
)
# Removes unused haves, unused tactics, renames unused vars to _
```

Available simplifications: `remove_unused_tactics`, `remove_unused_haves`, `rename_unused_vars`.

### 8. Extract sorry goals as standalone lemmas

```python
result = await client.sorry2lemma(
    content=partial_proof,
    environment="lean-4.28.0",
    extract_sorries=True,
    extract_errors=True,
)
# result.lemma_names -> names of extracted subgoal lemmas
# result.content -> code with extracted lemmas prepended
```

### 9. Merge multiple proof files

```python
result = await client.merge(
    documents=[code1, code2, code3],
    environment="lean-4.28.0",
    use_def_eq=True,  # deduplicate by definitional equality
)
```

Merge handles: deduplication of identical theorems, conflict resolution via renaming, preference for error-free/sorry-free proofs, topological ordering of dependencies. Normalize files first for best results.

### 10. Normalize before merge

```python
result = await client.normalize(
    content=messy_code,
    environment="lean-4.28.0",
)
# Removes sections/namespaces (fully qualifies names), deduplicates open commands,
# splits "open X in" syntax
```

## Response Structure

All responses share this shape:
- `okay` (bool) -- on check/verify_proof/repair_proofs
- `content` (str) -- transformed Lean code
- `lean_messages.errors/warnings/infos` -- compiler messages (now include end positions: `-:4:38-4:43: error: ...`)
- `tool_messages.errors/warnings/infos` -- tool-specific messages
- `timings` (dict) -- timing breakdown in ms
- Tool-specific: `documents`, `simplification_stats`, `repair_stats`, `disproved_theorems`, `lemma_names`, `normalize_stats`

## Error Handling

```python
from axle.exceptions import (
    AxleApiError,           # base class for all API errors
    AxleIsUnavailable,      # 503 -- auto-retried
    AxleRateLimitedError,   # 429 -- auto-retried
    AxleInvalidArgument,    # 400 -- fix your request
    AxleForbiddenError,     # 403 -- check credentials
    AxleNotFoundError,      # 404 -- check endpoint
    AxleConflictError,      # 409 -- resolve conflict
    AxleInternalError,      # 500 -- report bug
    AxleRuntimeError,       # timeout/OOM -- simplify input
)

try:
    result = await client.check(...)
except AxleInvalidArgument as e:
    print(f"Bad input: {e}")
except AxleRuntimeError as e:
    print(f"Runtime failure: {e}")
except AxleIsUnavailable as e:
    print(f"Service down: {e}")
```

Transient errors (503, 429) are automatically retried with exponential backoff. Non-retryable errors (400, 403, 404, 409, 500) raise immediately.

## Helper Utilities

```python
from axle import inline_lean_messages, remove_comments

annotated = inline_lean_messages(code, result.lean_messages.errors)
clean = remove_comments(code, include_docstrings=True)
```

## CLI

```bash
axle check file.lean --environment lean-4.28.0
axle verify-proof statement.lean proof.lean --environment lean-4.28.0
axle extract-theorems file.lean -o output/ --environment lean-4.28.0
axle repair-proofs broken.lean --environment lean-4.28.0
axle disprove conjecture.lean --environment lean-4.28.0
axle environments
```

Key CLI patterns:
- All commands require `--environment`
- Use `-` for stdin: `cat file.lean | axle check - --environment lean-4.28.0`
- Use `-o` for output file, `-f` to force overwrite
- Use `--strict` for non-zero exit on validation failure
- Use `--json` for JSON output
- Lists: `--names foo,bar,baz`
- Dicts: `--declarations foo=bar,old=new` or `--declarations '{"foo":"bar"}'`
- Boolean defaults: `--no-use-def-eq`, `--no-failsafe`
- Exit codes: 0=success, 1=error, 2=file exists, 3=validation failed (--strict), 130=interrupted

## HTTP API

All tools available at `POST https://axle.axiommath.ai/api/v1/<tool_name>`:

```bash
curl -s -X POST https://axle.axiommath.ai/api/v1/check \
    -H "Authorization: Bearer $AXLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"content": "import Mathlib\n#eval 2+2", "environment": "lean-4.28.0"}' | jq
```

## Troubleshooting

- **Import mismatch errors**: Your imports don't match the environment. Either match them to the environment header, or set `ignore_imports=True` (AXLE replaces imports with the environment's defaults).
- **Unsupported constructs**: `open`, `section`/`namespace`, non-standard declarations may cause unexpected behavior. Use `normalize` first.
- **okay=False but code compiles**: `verify_proof` and `check` apply stricter validation than the Lean compiler (e.g., rejecting `native_decide`, checking type signatures match).
- **"All executors failed"**: OOM or timeout on server side. Simplify input or break into smaller pieces.
- **Slow requests**: Cold environments need warmup. Server-reported timings reflect processing time, not total round-trip including queue wait.
- **Tool not working as expected**: AXLE handles proof-body errors well. Syntax errors or malformed declarations outside the proof body may cause issues. Rule of thumb: if the input compiles, the output should compile.

## Important Notes

- Input code should compile cleanly (except for sorry in proof bodies) for best results
- `timeout_seconds` defaults to 120, max 300 for non-admin requests
- Maintenance window: Wednesdays at 10:00 AM Pacific
- Lean messages include end positions (v1.1.0): `-:4:38-4:43: error: ...`
