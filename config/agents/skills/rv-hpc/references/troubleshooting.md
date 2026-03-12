# Troubleshooting rv Jobs

## Table of Contents
- [Quick Diagnosis Flow](#quick-diagnosis-flow)
- [Job Failed](#job-failed)
- [Job Stuck PENDING](#job-stuck-pending)
- [Job Hangs (RUNNING but no progress)](#job-hangs)
- [Out of Memory (OOM)](#out-of-memory)
- [Dependency Issues](#dependency-issues)
- [File and Output Issues](#file-and-output-issues)
- [Connection Issues](#connection-issues)
- [Multi-Node Issues](#multi-node-issues)

## Quick Diagnosis Flow

```
Job submitted → what happened?
├── Never started (PENDING)  → see "Job Stuck PENDING"
├── Started then failed      → rv logs <id> --err  → see "Job Failed"
├── Running but no output    → see "Job Hangs"
└── Ran but output missing   → see "File and Output Issues"
```

Always check stderr first: `rv logs <id> --err`. The real error is almost always there, not in stdout.

## Job Failed

### Step 1: Read stderr
```bash
rv logs <id> --err
```

### Common errors

**ModuleNotFoundError / ImportError**
```
ModuleNotFoundError: No module named 'flash_attn'
```
CUDA-dependent packages (flash-attn, auto-gptq, mamba-ssm) install on the compute node in phase 2. If they fail:
- Check that `requirements.txt` lists the correct version
- Some packages need specific CUDA versions — check compatibility
- Try pinning: `flash-attn==2.5.8`

**CUDA out of memory**
See [Out of Memory](#out-of-memory) section.

**NCCL errors**
```
NCCL error: unhandled system error
RuntimeError: NCCL communicator was aborted
```
Usually means one process crashed and NCCL can't recover:
- Check stderr for the root cause error BEFORE the NCCL message
- Often an OOM on one rank that cascades

**Permission denied on shared HF cache**
```
PermissionError: [Errno 13] Permission denied: '/standard/lab/hf_cache/...'
```
Shared cache needs group-writable setgid permissions. Check with your lab admin or use personal cache instead.

**Timeout (SIGUSR1 / SIGTERM)**
Job exceeded walltime. Either:
- Increase `--time` (but try to stay under 3h for backfill)
- Add checkpoint-restart support (SIGUSR1 handler)
- Optimize training to be faster (mixed precision, fewer logging steps)

## Job Stuck PENDING

The smart allocator submits to multiple partitions. If everything is PENDING:

### Check queue status
```bash
rv status  # shows GPU availability across partitions
```

### Strategies to get unstuck
1. **Try a different GPU type**: `rv run -g 1 -t a6000` instead of a100
2. **Use MIG**: `rv run --mig python train.py` (free, instant, 10 GB VRAM)
3. **Reduce walltime**: `--time 2:59:00` or shorter enables backfill scheduling
4. **Reduce GPU count**: fewer GPUs = more scheduling options
5. **Check allocation**: `rv status` shows your Slurm account and any limits

### Understanding wait times
- **Backfill**: sub-3h jobs can fill gaps in the schedule — often start within minutes
- **Regular queue**: depends on demand, can be hours to days for popular GPU types
- **MIG**: always instant (dedicated free pool)

## Job Hangs

Job shows RUNNING in `rv ps` but produces no output or stops making progress.

### Diagnosing hangs

```bash
rv logs -f              # check if output is still being produced
rv gpu                  # check GPU utilization
rv logs --err           # check for warnings/errors
```

### Common causes

**Mismatched collective operations**
All ranks must call the same collective ops (all_reduce, barrier, broadcast) in the same order. If one rank takes a different code path, all ranks hang waiting.

Fix: ensure all ranks execute the same control flow. Watch for `if rank == 0: ... ` blocks that contain collective ops.

**Data loader length mismatch across ranks**
If datasets are different sizes per rank, one rank finishes its epoch before others → hangs at the next sync point.

Fix: use `DistributedSampler` which pads shorter datasets. Or use `drop_last=True` on DataLoader.

**Missing barrier**
One rank proceeds past a point where others are still waiting.

Fix: add `dist.barrier()` at synchronization points.

**NCCL timeout**
Default NCCL timeout is 30 minutes. Large models or slow interconnects may need more:
```python
import datetime
dist.init_process_group(backend="nccl", timeout=datetime.timedelta(seconds=1800))
```
Or set via environment: `rv env set NCCL_TIMEOUT 1800`

**Deadlock in data loading**
`num_workers > 0` with certain datasets can deadlock. Try `num_workers=0` to isolate.

**Stuck on model download**
First run downloads from HuggingFace — can take a long time for large models. Check `rv logs -f` for download progress. Subsequent runs use the cached model.

## Out of Memory

### GPU OOM

```
torch.cuda.OutOfMemoryError: CUDA out of memory
```

**Solutions (in order of preference):**

1. **Mixed precision**: BF16 on A100/H200, FP16 on older GPUs — halves model memory
2. **Gradient accumulation**: Reduce `batch_size`, accumulate over N steps
   ```python
   for i, batch in enumerate(dataloader):
       loss = model(batch) / accumulation_steps
       loss.backward()
       if (i + 1) % accumulation_steps == 0:
           optimizer.step()
           optimizer.zero_grad()
   ```
3. **Activation checkpointing**: Recompute activations during backward instead of storing them (see gpu-training.md)
4. **Use more GPUs**: DDP splits batch across GPUs
5. **FSDP**: Shard model parameters across GPUs (FULL_SHARD for maximum savings)
6. **Use a bigger GPU**: a100_80 (80 GB) or h200 (141 GB)
7. **CPU offload with FSDP**: Last resort — saves 29% memory but 26x slower

**Memory estimation:**
- Inference: `params × 2 bytes (FP16)` + ~10% overhead
- Training: `params × 2 bytes (FP16) × 4` (model + gradients + 2 optimizer states)
- Example: 7B params in FP16 = ~14 GB inference, ~56 GB training

### System (CPU) OOM

```
Killed (signal 9)
```

Job exceeded allocated system memory. Override with `--mem`:
```bash
rv run -g 4 -t a100 --mem 200G python train.py
```

Rule of thumb: system memory should be 2-3x total VRAM. Common causes:
- Large dataset loaded into CPU memory
- Many dataloader workers each with their own copy
- FSDP CPU offload
- Model checkpoint gathering to rank 0

## Dependency Issues

### Wrong Python/CUDA version
rv uses the system Python and CUDA on the cluster. Check with:
```bash
rv exec "python --version"
rv exec "nvidia-smi"  # shows CUDA driver version (login node)
```

### Package conflicts
rv uses `uv pip install` from `requirements.txt` or `pyproject.toml`. If deps conflict:
- Pin specific versions in `requirements.txt`
- Use `rv exec "pip list"` to check what's installed in the venv
- CUDA-dependent packages install on compute nodes — errors only show up at job runtime

### Stale venv
If you've significantly changed deps and the venv seems stale:
```bash
rv exec "rm -rf /scratch/$USER/.rv/envs/{project}/{branch}"
```
Next `rv run` will create a fresh venv.

### Manual dependency management in shell commands
Shell commands (`rv run "bash train.sh"`) skip auto dep management. Inside your script:
```bash
#!/bin/bash
pip install -r requirements.txt  # installs into rv's active venv
python train.py
```

## File and Output Issues

### "My output files disappeared"
Files written to relative paths land in an immutable snapshot pruned after 7 days. Write to:
- `$RV_OUTPUT_DIR` for outputs
- `$RV_CHECKPOINT_DIR` for checkpoints
- Absolute `/scratch/` paths
- Use `rv run --output model.pt,results/` to persist specific relative paths

### "My data files aren't on the cluster"
Only git-tracked files are synced. Large data should already be on `/scratch/` or `/standard/`:
```bash
rv exec "ls /scratch/$USER/data/"
```

Upload data separately:
```bash
rv sync push  # only syncs git-tracked project files
# For large data, use scp/rsync directly to the HPC
```

### "Can't find my logs"
```bash
rv logs             # most recent job stdout
rv logs <id>        # specific job
rv logs --err       # stderr
rv logs --pull      # download log files locally
```

Logs live at `/scratch/{user}/.rv/logs/` on the cluster.

## Connection Issues

### "rv can't connect"
1. **VPN**: Must be on UVA Anywhere VPN
2. **SSH**: Test with `ssh uva-hpc` (or whatever your SSH config alias is)
3. **Config**: Check `~/.rv/config.toml` for correct hostname and user
4. **Re-init**: `rv init --force` to redo setup

### "Port forwarding isn't working"
```bash
rv forward -l          # check active forwards
rv forward -s          # stop all, then retry
rv forward --auto      # auto-detect services
```

Port forward requires the job to be RUNNING and the service to be listening. Check with `rv gpu` that the job is still active.

## Multi-Node Issues

### Logs from a specific node
```bash
rv logs --node 0       # first node
rv logs --node 1       # second node
rv logs --err --node 1 # stderr from second node
```

### One node crashed
Check per-node logs. One node's error often causes NCCL failures on others. Find the node that errored first — that's the root cause.

### Slow multi-node training
- Use A100 (80GB) or H200 — they have InfiniBand and NVLink interconnects
- Other GPU types use slower Ethernet for cross-node communication
- Consider `--single-node` if the model fits on one node's GPUs
- Set `NCCL_DEBUG=INFO` via `rv env set` to diagnose communication bottlenecks
