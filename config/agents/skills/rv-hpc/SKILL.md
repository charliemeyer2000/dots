---
name: rv-hpc
description: Submit GPU jobs to UVA's Rivanna/Afton HPC cluster using the rv CLI. Use this skill whenever the user mentions rv, Rivanna, Afton, HPC GPU jobs, SLURM on Rivanna, training on the cluster, or running Python/ML workloads on remote GPUs. Also trigger when users discuss multi-GPU training with torchrun on HPC, distributed training setup for Rivanna, debugging failed GPU jobs on the cluster, checkpoint-restart for long training runs, or port forwarding from compute nodes. Even if the user just says "submit this to the cluster" or "run this on GPUs", use this skill.
---

# rv CLI — HPC GPU Job Submission

rv runs locally and orchestrates GPU jobs on UVA's Rivanna/Afton HPC over SSH. No SLURM scripts needed — rv handles partition selection, dependency installation, file sync, and job lifecycle.

## The Three Things That Break Jobs

Almost every rv failure traces back to one of these. Internalize them before writing any rv command.

### 1. rv flags go before the command

rv flags and your script's flags share the same command line. If rv flags come after the script name, they silently pass to your script instead — rv never sees them.

```bash
# Correct — rv sees -g 4 and -t a100
rv run -g 4 -t a100 python train.py --lr 0.001

# Wrong — rv gets 1 default GPU; Python gets -g 4 and -t a100 as unknown args
rv run python train.py -g 4 -t a100
```

### 2. Use relative paths for your scripts

rv syncs your project to the cluster and runs your command inside a snapshot of it. Relative paths resolve against this snapshot, which means the venv is active and your dependencies are available.

Absolute script paths bypass this entirely — the system's `torchrun` or `python` (Python 3.6, no packages) may run instead, causing `ModuleNotFoundError` for everything.

```bash
# Correct — resolves within the workspace snapshot
rv run -t a100 -- torchrun --nproc_per_node=4 train.py
rv run python eval.py --config configs/eval.yaml

# Wrong — bypasses workspace, likely uses system Python 3.6
rv run torchrun /scratch/user/sft/train_sft.py
```

Absolute paths are fine for **data** (datasets, model weights on `/scratch/`), just not for scripts.

### 3. rv manages your Python — don't fight it

rv creates a persistent venv at `/scratch/{user}/.rv/envs/{project}/{branch}/` with Python 3.12, installs deps from your `requirements.txt` or `pyproject.toml` via `uv pip install`, and activates it in every job. The system Python on Rivanna is 3.6 and cannot run modern ML code.

The venv's `python`, `torchrun`, `pip`, and all entry points are on PATH automatically. Don't create manual venvs, use `uv sync`/`uv run`, or `conda` — they conflict with rv's environment. Don't `pip install` via `rv exec` either (exec runs on the login node without the venv).

For the full dependency lifecycle (two-phase install, shell vs Python commands, troubleshooting), read `references/dependencies.md`.

## Commands

### Submit and run
```bash
rv run -t a100 python train.py                    # batch job (returns immediately)
rv run -t a100 -f python train.py                  # batch + follow logs
rv run --mig python train.py                       # free MIG test (10 GB, instant)
rv run -g 2 -t a6000 -- torchrun --nproc_per_node=2 train.py   # multi-GPU
rv run -g 4 -t a100 --single-node python generate.py           # inference (no multi-node)
rv run --output ./artifacts ./results python train.py           # persist relative paths
rv up -g 1 -t a6000                                # interactive shell
```

### Monitor and manage
```bash
rv ps                    # active jobs
rv ps -a                 # include completed/failed (last 7 days)
rv logs                  # stdout of most recent job
rv logs --err            # stderr — check here first for errors
rv logs -f               # tail/follow live logs
rv gpu                   # nvidia-smi for most recent running job
rv status                # dashboard: connection, storage, jobs, GPU availability
rv stop <id-or-name>     # cancel a job (strategy-group-aware)
rv stop -a               # cancel all jobs
```

### Port forwarding
```bash
rv forward 8888          # forward specific port
rv forward --auto        # auto-detect Jupyter, TensorBoard, Ray
rv forward -l            # list active forwards
rv forward -s            # stop all forwards
```

### Files and environment
```bash
rv sync push             # push local → cluster (git-aware)
rv sync pull             # pull cluster → local
rv env set KEY VALUE     # set env var for all future jobs
rv env import .env       # bulk import from dotenv
rv cost -g 2 -t a100 --time 3h   # estimate SU cost
```

See `references/commands.md` for the full flag reference.

## GPU Selection

| Type | VRAM | SU/GPU-hr | Best For |
|------|------|-----------|----------|
| mig | 10 GB | FREE | Pipeline validation, small inference |
| a6000 | 48 GB | 143 | General training, medium models |
| a100_80 | 80 GB | 509 | Large models, multi-node (NVLink + InfiniBand) |
| h200 | 141 GB | 817 | Largest models, fastest |

Memory rules of thumb:
- **Inference**: `params × bytes_per_param × 1.1` (7B in FP16 ≈ 15 GB)
- **Training**: `params × bytes_per_param × 4` (7B in FP16 ≈ 56 GB)
- **System memory**: auto-calculated; override with `--mem 200G` if needed

Always validate on MIG first (`rv run --mig ...`) — it's free and instant.

## Output Persistence

Jobs run inside snapshots that get pruned after 7 days. Write important data to persistent locations:

- `os.environ["RV_OUTPUT_DIR"]` — per-job persistent output directory
- `os.environ["RV_CHECKPOINT_DIR"]` — keyed by job name, so same `--name` shares checkpoints across runs
- Absolute `/scratch/` paths
- `rv run --output model.pt,results/` — copies relative paths out of the snapshot after completion

Never write important data to relative paths (pruned) or `/tmp/` (node-local, lost at job end).

## Smart Allocator

rv doesn't submit to a single partition. It probes all partitions, generates compatible strategies, ranks by estimated wait time and cost, and submits the top strategies simultaneously — first to start wins, rest are cancelled. Preview with `rv run --dry-run`.

The default walltime of **2:59:00** is intentional — sub-3h jobs qualify for backfill scheduling, which often means near-instant allocation.

## Checkpoint-Restart

For jobs exceeding backfill windows, rv decomposes into backfill-sized segments. It sends `SIGUSR1` ~10 minutes before each segment expires — your code catches this, saves a checkpoint, and exits. rv auto-resubmits with the same `--name`, so `RV_CHECKPOINT_DIR` is shared for seamless resume.

See `references/gpu-training.md` for the implementation pattern (SIGUSR1 handler + resume logic).

## Environment

Every rv job automatically gets:
- `PYTHONUNBUFFERED=1` — real-time stdout
- `OMP_NUM_THREADS` — matched to allocated CPUs
- `HF_HOME`, `TORCH_HOME`, `TRITON_CACHE_DIR`, `WANDB_DIR` — all on scratch
- `RV_OUTPUT_DIR`, `RV_CHECKPOINT_DIR`, `RV_TOTAL_ELAPSED`

User env vars (`rv env set/import`) are injected into every job across all projects. Use them for credentials (HF_TOKEN, WANDB_API_KEY), not experiment config.

Config lives at `~/.rv/config.toml` — defaults for walltime, GPU type, AI job naming, email notifications, shared HF cache, scratch keepalive.

## Writing Training Scripts

When helping users write scripts for rv:

1. Use `RV_OUTPUT_DIR` and `RV_CHECKPOINT_DIR` for persistent I/O — don't hardcode paths
2. Keep a `requirements.txt` in the project root with all dependencies
3. Add SIGUSR1 handling if the job might exceed 3 hours (checkpoint-restart)
4. For torchrun, accept `--local_rank` / use `LOCAL_RANK` env var
5. Test on MIG first — `rv run --mig python train.py`

## Reference Files

Load these for deeper context when needed:

| Topic | Reference | When to Load |
|-------|-----------|--------------|
| Dependencies & environment | `references/dependencies.md` | ModuleNotFoundError, venv issues, GLIBCXX errors, dep install failures |
| Full command reference | `references/commands.md` | Detailed flags for specific commands |
| GPU training patterns | `references/gpu-training.md` | DDP, FSDP, multi-node, mixed precision, checkpoint-restart code, RLHF |
| Troubleshooting | `references/troubleshooting.md` | Debugging failed, hanging, or OOM jobs |
