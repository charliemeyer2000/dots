# rv Command Reference

All commands support `--json` for scripted/parseable output.

## rv init

Interactive setup wizard. Collects UVA computing ID, verifies VPN, sets up SSH keys, identifies Slurm account, creates cache symlinks, and optionally detects shared lab HuggingFace cache.

| Flag | Description |
|------|-------------|
| `--force` | Re-run setup even if already configured |

## rv up

Allocate GPUs and get an interactive shell. Uses the smart allocator.

| Flag | Description | Default |
|------|-------------|---------|
| `-g <n>` | Number of GPUs | 1 |
| `-t <type>` | GPU type (mig, a6000, a100_80, h200, etc.) | from config |
| `--time <duration>` | Walltime (HH:MM:SS) | 2:59:00 |
| `--name <name>` | Job name | auto-generated |
| `--mem <size>` | System memory (e.g., 200G) | auto-calculated |
| `--mig` | Use free instant MIG slice | false |
| `--dry-run` | Preview strategies without submitting | false |

## rv run

Submit batch jobs. Syncs local files, creates immutable snapshot, submits via smart allocator.

| Flag | Description | Default |
|------|-------------|---------|
| `-g <n>` | Number of GPUs | 1 |
| `-t <type>` | GPU type | from config |
| `--time <duration>` | Walltime | 2:59:00 |
| `--name <name>` | Job name (same name shares checkpoint dir) | auto-generated |
| `--mem <size>` | System memory | auto-calculated |
| `--mig` | Use free MIG slice | false |
| `-o, --output <paths>` | Comma-separated paths to persist from snapshot | none |
| `--single-node` | Prevent multi-node strategies | false |
| `-f, --follow` | Wait and tail logs after submission | false |
| `--dry-run` | Preview strategies | false |

**Argument ordering reminder**: rv flags MUST come before the command.
```bash
rv run -g 4 -t a100 python train.py          # correct
rv run -g 4 -t a100 -- torchrun ... train.py  # correct (use -- before torchrun)
rv run python train.py -g 4                   # WRONG
```

## rv ps (alias: rv ls)

List active jobs.

| Flag | Description |
|------|-------------|
| `-a, --all` | Include completed/failed from last 7 days |

Output columns: Job ID, Name, State, GPU Type, Node, Elapsed, Git Branch, Commit Hash.

## rv stop (alias: rv cancel)

Cancel jobs by ID or name.

| Flag | Description |
|------|-------------|
| `-a, --all` | Cancel all active jobs |

Automatically manages sibling strategies (no orphaned fan-out jobs). Also kills any active port forwards for the cancelled jobs.

## rv ssh

Attach to a running job's compute node.

| Flag | Description |
|------|-------------|
| (no args) | Attach to most recent running job |
| `<id-or-name>` | Attach to specific job |
| `--config` | Print SSH config entry for VS Code/Cursor |
| `--node <index>` | Attach to specific node in multi-node job |

## rv logs

View job output.

| Flag | Description |
|------|-------------|
| (no args) | Show most recent job's stdout |
| `<id-or-name>` | Show specific job |
| `--err` | Show stderr instead of stdout |
| `-f, --follow` | Tail/follow live output |
| `--pull` | Download log files locally |
| `--node <index>` | Filter to specific node in multi-node job |
| `--tail <n>` | Show last n lines |
| `--raw` | Disable progress bar filtering |

Multi-node jobs show merged output with `[node0]`, `[node1]` prefixes.

## rv status

Dashboard view: connection health, Slurm account, storage usage, active jobs, port forwards, GPU availability across all partitions.

## rv gpu

Show nvidia-smi for a job's allocated GPUs.

| Flag | Description |
|------|-------------|
| (no args) | Most recent running job |
| `<id-or-name>` | Specific job |
| `--node <index>` | Specific node in multi-node job |

## rv sync

File transfer via rsync.

### rv sync push
Push local files to cluster. Git-aware path targeting.

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview without transferring |

### rv sync pull
Pull files from cluster to local.

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview without transferring |

### rv sync watch
Auto-push on local file changes. Runs until cancelled.

## rv forward

Port forwarding from compute nodes.

| Flag | Description |
|------|-------------|
| `<port>` | Forward a specific port |
| `--auto` | Auto-detect common services (Jupyter, TensorBoard, Ray) |
| `-l, --list` | List active port forwards (also prunes forwards for dead jobs) |
| `-s, --stop [port]` | Stop forwards (all or specific port) |
| `--node <index>` | Forward from specific node in multi-node job |

## rv env

Manage environment variables injected into every job.

| Subcommand | Description |
|------------|-------------|
| `rv env set KEY value` | Set a variable |
| `rv env import <file>` | Import from .env file |
| `rv env list` | Show all user-set variables |
| `rv env rm KEY` | Remove a variable |

## rv cost

Estimate SU costs.

| Flag | Description |
|------|-------------|
| `-g <n>` | Number of GPUs |
| `-t <type>` | GPU type |
| `--time <duration>` | Walltime |

With no flags, shows cost table for all GPU types. MIG is always free (0 SU).

## rv exec

Run commands on the login node (no GPU allocation).

| Flag | Description | Default |
|------|-------------|---------|
| `--timeout <seconds>` | Max execution time | 120 |

```bash
rv exec "ls /scratch/$USER/data"
rv exec "du -sh /scratch/$USER/.rv/"
rv exec --timeout 300 "uv pip install vllm"
```

For quick file checks, listing dirs, verifying data exists before submitting a job. Use `--timeout` for slow operations like installing large packages.

## rv upgrade

Self-update rv to the latest version. Also auto-checks once per day.

## Remote File Paths

| Path | Purpose |
|------|---------|
| `/scratch/{user}/.rv/logs/` | Job output logs |
| `/scratch/{user}/.rv/outputs/` | Persistent outputs (RV_OUTPUT_DIR) |
| `/scratch/{user}/.rv/checkpoints/{jobName}/` | Persistent checkpoints (RV_CHECKPOINT_DIR) |
| `/scratch/{user}/.rv/envs/{project}/{branch}/` | Python venvs |
| `/scratch/{user}/rv-workspaces/{project}/{branch}/code/` | Mutable workspace |
| `/scratch/{user}/rv-workspaces/{project}/{branch}/snapshots/` | Per-job snapshots |
| `~/.cache/{huggingface,uv,pip,wandb,triton,torch}` | Symlinked to /scratch |
