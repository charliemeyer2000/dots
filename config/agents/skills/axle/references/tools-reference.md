# AXLE Tools -- Complete Parameter Reference

## check

Evaluate Lean code and collect all messages. Use to check if code is valid or get output of `#check` / `#eval`.

```python
result = await client.check(
    content: str,                    # Lean source code (required)
    environment: str,                # e.g. "lean-4.28.0" (required)
    mathlib_linter: bool = False,    # enable Mathlib linters
    ignore_imports: bool = False,    # skip import validation
    timeout_seconds: float = 120,    # max 300 for non-admin
) -> CheckResponse
```

**Response**: `okay`, `content`, `lean_messages`, `tool_messages`, `failed_declarations`, `timings`

---

## verify_proof

Validate a candidate proof matches a formal statement's type signature.

```python
result = await client.verify_proof(
    formal_statement: str,           # sorried theorem to verify against (required)
    content: str,                    # candidate proof (required)
    environment: str,                # (required)
    permitted_sorries: list[str] = None,  # theorems allowed to use sorry
    mathlib_linter: bool = False,
    use_def_eq: bool = True,         # definitional equality for type comparison
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> VerifyProofResponse
```

**Response**: `okay`, `content`, `lean_messages`, `tool_messages`, `failed_declarations`, `timings`

**Verification error patterns** (`tool_messages.errors`):

| Pattern | Meaning |
|---------|---------|
| `Missing required declaration '{name}'` | Symbol absent from content |
| `Kind mismatch for '{name}': candidate has {X} but expected {Y}` | theorem vs def mismatch |
| `Theorem '{name}' does not match expected signature: expected {X}, got {Y}` | Type changed |
| `Definition '{name}' does not match expected signature: expected {X}, got {Y}` | Type/value of def changed |
| `Unsafe/partial function '{name}' detected` | Disallowed function |
| `In '{name}': Axiom '{axiom}' is not in the allowed set of standard axioms` | Disallowed axiom |
| `Declaration '{name}' uses 'sorry' which is not allowed` | Unpermitted sorry |
| `Candidate uses banned 'open private' command` | Disallowed open private |

**`permitted_sorries` tip**: To allow `native_decide`, include `["Lean.trustCompiler", "Lean.ofReduceBool", "Lean.ofReduceNat"]`.

**Security**: verify_proof trusts the Lean environment. Crafted metaprogramming can make invalid proofs appear valid. For adversarial settings, use lean4checker, Comparator, or SafeVerify.

---

## extract_theorems

Split a multi-theorem file into self-contained documents with dependency tracking.

```python
result = await client.extract_theorems(
    content: str,                    # (required)
    environment: str,                # (required)
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> ExtractTheoremsResponse
```

**Response**: `content`, `lean_messages`, `tool_messages`, `documents` (dict[str, Document]), `timings`

**Document fields**: `declaration`, `content` (standalone), `tokens` (list[str]), `signature`, `type`, `type_hash`, `is_sorry`, `index`, `line_pos`, `end_line_pos`, `proof_length`, `tactic_counts`, `local_type_dependencies`, `local_value_dependencies`, `external_type_dependencies`, `external_value_dependencies`, `local_syntactic_dependencies`, `external_syntactic_dependencies`, `theorem_messages`

Note: `document_messages` was removed in v1.1.0. To replicate, run each document's `content` through `check`.

---

## theorem2sorry

Strip proof bodies, replacing with `sorry`.

```python
result = await client.theorem2sorry(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,        # specific theorems by name
    indices: list[int] = None,      # by 0-based index (negative OK)
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> Theorem2SorryResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`

---

## repair_proofs

Attempt to fix broken theorem proofs.

```python
result = await client.repair_proofs(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    repairs: list[str] = None,       # all if omitted
    terminal_tactics: list[str] = ["grind"],
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> RepairProofsResponse
```

**Available repairs**:
- `remove_extraneous_tactics` -- removes tactics after proof is already complete
- `apply_terminal_tactics` -- tries terminal tactics in place of sorries (uses `terminal_tactics` param)
- `replace_unsafe_tactics` -- replaces `native_decide` with `decide +kernel`, etc.

**Response**: `okay`, `lean_messages`, `tool_messages`, `content`, `timings`, `repair_stats`

**Limitations**: No guarantee repaired proofs are semantically correct. Complex multi-goal proofs may need manual intervention.

---

## simplify_theorems

Remove unnecessary tactics and clean up proofs.

```python
result = await client.simplify_theorems(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    simplifications: list[str] = None,  # all if omitted
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> SimplifyTheoremsResponse
```

**Available simplifications**:
- `remove_unused_tactics` -- removes tactics that don't contribute to the proof
- `remove_unused_haves` -- removes unused `have` statements
- `rename_unused_vars` -- replaces unused variable names with `_`

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`, `simplification_stats`

---

## disprove

Attempt to disprove theorems by proving the negation (via Plausible counterexample search).

```python
result = await client.disprove(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    terminal_tactics: list[str] = ["grind"],
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> DisproveResponse
```

**Response**: `content`, `lean_messages`, `tool_messages`, `results` (dict[str, str]), `disproved_theorems`, `timings`

---

## have2lemma

Extract `have` statements into standalone top-level lemmas.

```python
result = await client.have2lemma(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    include_have_body: bool = False,      # include proof body in extracted lemma
    include_whole_context: bool = True,   # include full context (skip cleanup)
    reconstruct_callsite: bool = False,   # replace have with lemma call
    verbosity: int = 0,                   # 0-2; higher = more type annotations
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> Have2LemmaResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `lemma_names`, `timings`

**Option caveats**:
- `include_have_body=True` is NOT guaranteed robust -- Lean may revert variables, breaking the proof body
- `include_whole_context=False` may drop hypotheses Lean judges irrelevant but that the proof actually needs (e.g., `assumption` tactic)
- `reconstruct_callsite=True` fails when inaccessible variables exist (e.g., after `intros` without explicit names)
- `verbosity=2` produces extremely verbose but unambiguous type signatures -- use when coercions/casts cause inference errors

---

## have2sorry

Replace `have` statement proof bodies with `sorry`.

```python
result = await client.have2sorry(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> Have2SorryResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`

---

## sorry2lemma

Extract `sorry` placeholders and error locations into standalone lemmas.

```python
result = await client.sorry2lemma(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    extract_sorries: bool = True,
    extract_errors: bool = True,
    include_whole_context: bool = True,
    reconstruct_callsite: bool = False,
    verbosity: int = 0,
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> Sorry2LemmaResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `lemma_names`, `timings`

When a single sorry applies to multiple goals (e.g., after `<;>`), generates multiple lemmas combined with `first`.

---

## merge

Combine multiple Lean files with deduplication and conflict resolution.

```python
result = await client.merge(
    documents: list[str],              # list of Lean code strings (required)
    environment: str,                  # (required)
    use_def_eq: bool = True,           # deduplicate by definitional equality
    include_alts_as_comments: bool = False,  # preserve alternate proofs as comments
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> MergeResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`

**Merge behavior**:
- Non-declaration commands (open, variable, set_option) extracted first under comment labels
- Declarations merged in topological dependency order
- Same-name different-type declarations: auto-renamed (e.g., `A` -> `A_1`)
- Same-type declarations: deduplicated (prefers error-free, sorry-free proofs)
- Different-name same-type declarations: merged with auto-generated unique name
- Failed proofs preserved as `-- unsuccessful attempt` comments
- **Normalize first** for best results (sections/namespaces can cause issues)

---

## rename

Rename declarations and update all references.

```python
result = await client.rename(
    content: str,                    # (required)
    declarations: dict[str, str],    # {"old_name": "new_name"} (required)
    environment: str,                # (required)
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> RenameResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`

Handles namespaced declarations (use fully qualified names), inductive type constructor references, and all cross-references throughout the file.

---

## theorem2lemma

Convert between `theorem` and `lemma` keywords.

```python
result = await client.theorem2lemma(
    content: str,                    # (required)
    environment: str,                # (required)
    names: list[str] = None,
    indices: list[int] = None,
    target: str = "lemma",           # "lemma" or "theorem"
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> Theorem2LemmaResponse
```

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`

---

## normalize

Standardize Lean formatting for compatibility with other tools (especially `merge`).

```python
result = await client.normalize(
    content: str,                    # (required)
    environment: str,                # (required)
    normalizations: list[str] = None,  # defaults: remove_sections, remove_duplicates, split_open_in_commands
    failsafe: bool = True,             # return original if normalization fails
    ignore_imports: bool = False,
    timeout_seconds: float = 120,
) -> NormalizeResponse
```

**Available normalizations**:
- `remove_sections` -- removes section/namespace/end, fully qualifies declaration names
- `expand_decl_names` -- fully qualifies names by prepending enclosing namespaces
- `remove_duplicates` -- removes repeated open/variable commands
- `split_open_in_commands` -- splits `open X in decl` into separate `open X` + `decl`
- `normalize_module_comments` -- converts `/-! ... -/` to `/- ... -/`
- `normalize_doc_comments` -- converts `/-- ... -/` to `/- ... -/`

**Response**: `lean_messages`, `tool_messages`, `content`, `timings`, `normalize_stats`
