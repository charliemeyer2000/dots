# Dependencies & Environment Reference

## How rv's Venv Works End-to-End

When you run `rv run python train.py`:

1. rv syncs git-tracked files to `/scratch/{user}/rv-workspaces/{project}/{branch}/code/`
2. Creates/reuses a persistent venv at `/scratch/{user}/.rv/envs/{project}/{branch}/`
3. Installs deps from `requirements.txt` or `pyproject.toml` via `uv pip install` (skipped if deps hash unchanged)
4. Creates a hardlink snapshot of the code directory
5. Generates a SLURM script that:
   - Loads `cuda/12.8.0` and `miniforge/24.11.3-py3.12` modules
   - Activates the venv (`source .../bin/activate`)
   - Runs phase 2 dep install if needed (CUDA packages)
   - Sets environment variables (caches, output dirs, etc.)
   - `cd`s into the snapshot
   - Runs your command

**Inside the job, PATH looks like:**
```
/scratch/{user}/.rv/envs/{project}/{branch}/bin   ← venv (python 3.12, torchrun, pip)
/apps/software/.../miniforge/24.11.3-py3.12/bin   ← module-loaded Python
/usr/bin                                           ← system Python 3.6 (NEVER USE)
```

## Relative vs Absolute Paths

**The #1 source of agent bugs with rv.**

Your command runs from within a snapshot copy of your project. Relative paths resolve against this snapshot.

```bash
# CORRECT
rv run -t a100 -- torchrun --nproc_per_node=4 train.py
rv run python eval.py --config configs/eval.yaml
rv run python -m mypackage.train

# WRONG — bypasses workspace, may use system torchrun/python
rv run torchrun /scratch/user/sft/train_sft.py
rv run python /scratch/user/some_script.py
```

**Why absolute script paths are dangerous:**
- The script may be outside the venv's scope — system `torchrun` (Python 3.6) gets invoked instead of venv's
- Working directory expectations break — the script's relative imports and config paths fail
- rv's sync + snapshot system is designed so you never need absolute paths to your own code

**Absolute paths ARE fine for data:**
```python
# OK — data can be anywhere on scratch
dataset = load_dataset("json", data_files="/scratch/user/data/train.jsonl")
model = AutoModel.from_pretrained("/scratch/user/.cache/huggingface/models/...")
```

## Two-Phase Dependency Install

**Phase 1 (login node, before job submission):**
- Creates venv with `uv venv` using module-loaded Python 3.12
- Runs `uv pip install -r requirements.txt` (or `-e .` for pyproject.toml)
- On failure: falls back to per-package install, skipping CUDA-dependent packages
- Writes `.needs-phase2` marker if anything was skipped

**Phase 2 (compute node, at job start):**
- Only runs if `.needs-phase2` exists
- Loads `gcc/11.4.0` for compilation
- Retries full install with `--no-build-isolation` (GPU + gcc available)
- Removes marker on success

**Packages that typically need phase 2:** flash-attn, auto-gptq, mamba-ssm, triton (kernel compilation), anything requiring CUDA at build time.

**Reinstall triggers:**
- SHA-256 hash of deps file changes → full reinstall
- Venv deleted manually → recreated from scratch
- New branch → new venv (branches are isolated)

## torchrun Integration

torchrun is installed into the venv as part of PyTorch (from `requirements.txt` or `pyproject.toml`). rv doesn't do anything special — venv activation puts it on PATH.

rv auto-injects these flags:
- `--master-port=$MASTER_PORT` (per-job unique, range 29500-30499)
- For multi-node: `--nnodes`, `--node-rank`, `--master-addr`

DeepSpeed configs can use relative paths since CWD is the workspace snapshot:
```bash
rv run -g 4 -t a100 -- deepspeed --num_gpus=4 train.py --deepspeed ds_config.json
```

## Shell Commands and Dependency Management

| Command | Deps installed? | Venv active? |
|---------|----------------|--------------|
| `rv run python train.py` | Yes | Yes |
| `rv run torchrun train.py` | Yes | Yes |
| `rv run python -m module` | Yes | Yes |
| `rv run "bash train.sh"` | No | Yes |
| `rv run "make train"` | No | Yes |
| `rv exec "python ..."` | No | No (login node) |

The venv is always activated in job scripts. The difference is whether `uv pip install` runs before submission. Shell-wrapped commands skip dep install but can still use already-installed packages.

`rv exec` runs on the login node with NO venv activation — use it only for file operations, not Python work.

## Troubleshooting

### ModuleNotFoundError

**Diagnosis:** Add to your script:
```python
import sys
print(f"executable: {sys.executable}", flush=True)
print(f"version: {sys.version}", flush=True)
```

| sys.executable | Cause | Fix |
|---------------|-------|-----|
| `/usr/bin/python3` | System Python, venv not active | Use `rv run` with relative paths, not `rv exec` |
| `~/.local/bin/python` | User Python, not venv | Same as above |
| `/scratch/.../.rv/envs/.../bin/python` | Correct venv, package missing | Add to requirements.txt |

### GLIBCXX_3.4.29 not found

```
ImportError: /lib64/libstdc++.so.6: version `GLIBCXX_3.4.29' not found
```

System libstdc++ is too old. Fix:
```bash
rv env set LD_LIBRARY_PATH /apps/software/standard/core/gcc/14.2.0/lib64
```

### Phase 2 Install Failures

Check stderr: `rv logs <id> --err`

Common fixes:
- Pin compatible version: `flash-attn==2.5.8`
- Ensure torch is listed before CUDA-dependent packages in requirements.txt
- Check CUDA compatibility of the package version

### Stale Venv

```bash
rv exec "rm -rf /scratch/$USER/.rv/envs/{project}/{branch}"
```
Next `rv run` recreates from scratch. Check existing venvs:
```bash
rv exec "ls /scratch/$USER/.rv/envs/"
```

### Don't pip install into the system Python

**Never do:**
```bash
rv exec "pip install torch"              # targets system Python 3.6
rv exec "/usr/bin/pip install ..."       # same problem
```

**Instead:** add to requirements.txt, or use `rv up --mig` to get a shell with the venv active.

## Quick Verification Pattern

```bash
# test_env.py
import sys
print(f"Python: {sys.executable}")
print(f"Version: {sys.version}")
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA: {torch.cuda.is_available()}")
# add your critical imports here
```

```bash
rv run --mig --name test-deps python test_env.py
rv logs -f test-deps
```

Expected: executable under `/scratch/.../.rv/envs/`, Python 3.12.x, CUDA True.
