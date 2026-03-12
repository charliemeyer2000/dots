---
name: rv-hpc
description: Submit GPU jobs to UVA's Rivanna/Afton HPC cluster using the rv CLI. Use this skill whenever the user mentions rv, Rivanna, Afton, HPC GPU jobs, SLURM on Rivanna, training on the cluster, or running Python/ML workloads on remote GPUs. Also trigger when users discuss multi-GPU training with torchrun on HPC, distributed training setup for Rivanna, debugging failed GPU jobs on the cluster, checkpoint-restart for long training runs, or port forwarding from compute nodes. Even if the user just says "submit this to the cluster" or "run this on GPUs", use this skill.
---

# rv CLI — HPC GPU Job Submission

rv runs locally on your machine and orchestrates GPU jobs on UVA's Rivanna/Afton HPC over SSH. No SLURM scripts needed — rv handles partition selection, dependency installation, file sync, and job lifecycle.

## Critical Rules

These are the most common sources of bugs when working with rv. Every piece of advice in this skill flows from real failure modes.

### Argument ordering

rv flags go BEFORE the command. Getting this wrong silently passes flags to the user's script instead of rv — a nasty silent bug.

```bash
# Correct
rv run -g 4 -t a100 python train.py --lr 0.001

# WRONG — -g 4 gets passed to Python, rv allocates default (1) GPU
rv run python train.py -g 4 -t a100
```

### Virtual environment management

rv auto-manages Python venvs. It detects `requirements.txt` or `pyproject.toml`, creates a persistent venv at `/scratch/{user}/.rv/envs/{project}/{branch}/`, and installs deps via `uv pip install`. Two-phase install: login node handles most packages; compute node handles CUDA-dependent ones (flash-attn, auto-gptq, mamba-ssm, etc.).

**Do:**
- Let rv handle deps automatically
- Add `pip install` calls mid-script if needed (installs into the active venv)
- Keep a `requirements.txt` or `pyproject.toml` with your dependencies

**Do not:**
- Use `uv sync`, `uv run`, or create manual venvs — these conflict with rv's venv
- `unset VIRTUAL_ENV` — breaks the active environment
- Use `conda` — rv uses uv exclusively

**Bash vs Python**: Commands starting with `python` or `python3` get automatic dependency management. Shell commands like `rv run "bash train.sh"` or `rv run "make train"` skip it entirely. If wrapping Python in a shell script, manage deps yourself inside the script or ensure the command starts with `python`.

### Output persistence

Each job runs in an immutable snapshot that gets pruned after 7 days. Files written to relative paths are ephemeral.

Persist outputs by writing to:
- `os.environ["RV_OUTPUT_DIR"]` — persistent output directory
- `os.environ["RV_CHECKPOINT_DIR"]` — checkpoint dir, keyed by job name for cross-run resume
- Absolute `/scratch/` paths
- Or use `rv run --output model.pt,results/` to copy specific relative paths out of the snapshot

Never write important data to:
- Relative paths (land in pruned snapshots)
- `/tmp/` (node-local, lost when job ends)

### File sync

Only git-tracked files are transferred to the cluster. Use `.rvignore` for additional exclusions. Non-git projects fall back to `.gitignore` filtering. Large data files should already be on `/scratch/` or `/standard/` — don't try to sync them.

## Common Workflows

### Quick test on free GPU
```bash
rv run --mig python train.py
```
MIG slices (10 GB VRAM) are free and instant. Always validate your pipeline here first before requesting expensive GPUs.

### Single GPU training
```bash
rv run -g 1 -t a6000 python train.py
```

### Multi-GPU (single node)
```bash
rv run -g 2 -t a6000 -- torchrun --nproc_per_node=2 train.py
```

### Multi-GPU (may span multiple nodes)
```bash
rv run -g 4 -t a100 -- torchrun --nproc_per_node=2 train.py
```
rv handles srun + torchrun coordination across nodes automatically.

### Inference (force single node)
```bash
rv run -g 4 -t a100 --single-node python generate.py
```
Use `--single-node` because `device_map="auto"` only works within one node — it cannot shard across nodes.

### Interactive shell
```bash
rv up -g 1 -t a6000
```

### Monitor and manage jobs
```bash
rv ps                    # active jobs
rv ps -a                 # include completed/failed (last 7 days)
rv logs                  # stdout of most recent job
rv logs --err            # stderr — check here first for errors
rv logs -f               # tail/follow live logs
rv gpu                   # nvidia-smi for most recent job
rv status                # full dashboard: connection, storage, jobs, GPU availability
rv stop <id-or-name>     # cancel a job
rv stop -a               # cancel all jobs
```

### Port forwarding
```bash
rv forward 8888          # forward specific port
rv forward --auto        # auto-detect Jupyter, TensorBoard, Ray
rv forward -l            # list active forwards
rv forward -s            # stop all forwards
```

### File transfer
```bash
rv sync push             # push local → cluster (git-aware)
rv sync pull             # pull cluster → local
rv sync watch            # auto-push on local changes
```

### Environment variables
```bash
rv env set WANDB_PROJECT my-experiment
rv env import .env       # import from dotenv file
rv env list
rv env rm KEY
```

### Cost estimation
```bash
rv cost -g 2 -t a100 --time 3:00:00    # specific estimate
rv cost                                  # show all GPU types
```

## GPU Selection Guide

| Type | VRAM | SU/GPU-hr | Best For |
|------|------|-----------|----------|
| mig | 10 GB | FREE | Testing pipelines, small inference |
| a6000 | 48 GB | 142.73 | General training, medium models |
| a100_80 | 80 GB | 508.89 | Large models, multi-node (NVLink + InfiniBand) |
| h200 | 141 GB | 816.67 | Largest models |

Memory estimation:
- **Inference**: `params × bytes_per_param × 1.1` (e.g., 7B model in FP16 = ~15 GB)
- **Training**: `params × bytes_per_param × 4` (model + gradients + optimizer states)
- **System memory**: auto-calculated by rv; override with `--mem 200G` if needed (rule of thumb: 2-3x total VRAM)

Run `rv cost` or `rv status` for full GPU table and live availability.

## Smart Allocator

rv doesn't submit to a single partition. It:
1. Probes all partitions for GPU availability and queue depth
2. Generates all compatible strategies (GPU type, partition, single/multi-node, backfill, checkpoint-restart)
3. Ranks by estimated wait time and cost
4. Submits top strategies simultaneously — first to RUNNING wins, rest cancelled

Preview strategies with `rv up --dry-run` or `rv run --dry-run`.

The default walltime of **2:59:00** maximizes backfill eligibility — sub-3-hour jobs fit into scheduling gaps that longer jobs can't. Only increase walltime if your job genuinely needs it.

## Checkpoint-Restart

For jobs exceeding available backfill windows, rv decomposes into backfill-sized segments:
- Sends `SIGUSR1` ~10 minutes before each segment expires
- Your code must catch this signal and save a checkpoint
- rv auto-resubmits, tracking cumulative time via `RV_TOTAL_ELAPSED`
- Same `--name` shares the checkpoint directory for seamless resume

```python
import signal, os, torch

checkpoint_dir = os.environ["RV_CHECKPOINT_DIR"]
should_stop = False

def handle_preempt(signum, frame):
    global should_stop
    should_stop = True

signal.signal(signal.SIGUSR1, handle_preempt)

# Resume from checkpoint
ckpt_path = os.path.join(checkpoint_dir, "latest.pt")
start_epoch = 0
if os.path.exists(ckpt_path):
    ckpt = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    model.load_state_dict(ckpt["model"])
    optimizer.load_state_dict(ckpt["optimizer"])
    start_epoch = ckpt["epoch"] + 1

for epoch in range(start_epoch, num_epochs):
    train_one_epoch(model, optimizer, dataloader)
    torch.save({
        "model": model.state_dict(),
        "optimizer": optimizer.state_dict(),
        "epoch": epoch,
    }, ckpt_path)
    if should_stop:
        break  # rv will resubmit automatically
```

## Auto-Set Environment Variables

Every rv job gets these — don't set them yourself:
- `OMP_NUM_THREADS` — matched to allocated CPUs
- `PYTHONUNBUFFERED=1` — immediate stdout flushing
- `HF_HOME`, `TORCH_HOME`, `TRITON_CACHE_DIR`, `WANDB_DIR`, `VLLM_CACHE_DIR` — all on scratch
- `RV_CHECKPOINT_DIR` — persistent, keyed by job name
- `RV_OUTPUT_DIR` — persistent output location
- `RV_TOTAL_ELAPSED` — cumulative time across checkpoint-restart segments

User-managed env vars via `rv env set/import/list/rm` are injected into every job.

## Configuration

Config at `~/.rv/config.toml`. Key settings:
- `defaults.time` — walltime (default 2:59:00, keep under 3h for backfill)
- `defaults.gpu_type` — default GPU
- `defaults.ai_naming` — auto-generate creative job names
- `notifications.enabled` + `notifications.email` — email on COMPLETED/FAILED/TIMEOUT
- `shared.hf_cache` — shared lab HuggingFace cache path
- `scratch_keepalive.enabled` — touches files daily to prevent 90-day scratch purge (default true)

## Writing Training Scripts for rv

When helping users write training scripts that will run via rv:

1. **Use `RV_OUTPUT_DIR` and `RV_CHECKPOINT_DIR`** for all persistent I/O
2. **Don't hardcode paths** — use `os.environ` for rv-provided variables
3. **Add SIGUSR1 handling** if the job might use checkpoint-restart (any job over ~3 hours)
4. **Keep a `requirements.txt`** in the project root with all dependencies
5. **For torchrun scripts**, accept `--local_rank` / use `LOCAL_RANK` env var
6. **Log to wandb/stdout** — rv captures stdout/stderr automatically
7. **Test on MIG first** — `rv run --mig python train.py` (free, instant)

## Reference Files

Load these for deeper context:

| Topic | Reference | When to Load |
|-------|-----------|--------------|
| Full command reference | `references/commands.md` | User needs detailed flags for specific commands |
| GPU training patterns | `references/gpu-training.md` | DDP, FSDP, multi-node, mixed precision, RLHF |
| Troubleshooting | `references/troubleshooting.md` | Debugging failed, hanging, or OOM jobs |
