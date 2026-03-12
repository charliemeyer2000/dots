# GPU Training Patterns on Rivanna

## Table of Contents
- [Single GPU](#single-gpu)
- [Multi-GPU DDP](#multi-gpu-ddp)
- [FSDP](#fsdp)
- [Multi-Node Training](#multi-node-training)
- [Mixed Precision](#mixed-precision)
- [Checkpointing](#checkpointing)
- [Inference](#inference)
- [RLHF / GRPO](#rlhf--grpo)
- [Process Groups](#process-groups)

## Single GPU

```bash
# Free test
rv run --mig python train.py

# Production
rv run -g 1 -t a6000 python train.py
```

No special code changes needed. Use standard PyTorch training loops.

## Multi-GPU DDP

DistributedDataParallel replicates the model on each GPU and synchronizes gradients.

```bash
rv run -g 2 -t a6000 -- torchrun --nproc_per_node=2 train.py
```

Training script pattern:

```python
import os
import torch
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, DistributedSampler

def main():
    dist.init_process_group(backend="nccl")
    local_rank = int(os.environ["LOCAL_RANK"])
    torch.cuda.set_device(local_rank)

    model = MyModel().to(local_rank)
    model = DDP(model, device_ids=[local_rank])

    dataset = MyDataset()
    sampler = DistributedSampler(dataset)
    dataloader = DataLoader(dataset, sampler=sampler, batch_size=32)

    for epoch in range(num_epochs):
        sampler.set_epoch(epoch)  # critical for proper shuffling each epoch
        for batch in dataloader:
            # training step...
            pass

    dist.destroy_process_group()

if __name__ == "__main__":
    main()
```

**DDP gotchas:**
- Save with `model.module.state_dict()` — DDP wraps the model, so `.module` accesses the underlying model
- Never call `model.module.forward()` directly — always use `model(input)` so DDP can synchronize
- Set `sampler.set_epoch(epoch)` every epoch or shuffling is identical across epochs
- Use `find_unused_parameters=True` only for models with conditional forward paths
- Gradient accumulation: divide loss by accumulation steps, only call `optimizer.step()` every N steps

## FSDP

Fully Sharded Data Parallel shards model parameters, gradients, and optimizer states across GPUs. Use when models don't fit in single-GPU memory.

```bash
rv run -g 4 -t a100 -- torchrun --nproc_per_node=4 train.py
```

```python
import torch
from torch.distributed.fsdp import FullyShardedDataParallel as FSDP
from torch.distributed.fsdp import ShardingStrategy
from torch.distributed.fsdp.wrap import transformer_auto_wrap_policy
from transformers.models.llama.modeling_llama import LlamaDecoderLayer

# Wrap policy — wrap at the transformer layer level
wrap_policy = functools.partial(
    transformer_auto_wrap_policy,
    transformer_layer_cls={LlamaDecoderLayer},
)

model = FSDP(
    model,
    sharding_strategy=ShardingStrategy.FULL_SHARD,
    auto_wrap_policy=wrap_policy,
    device_id=torch.cuda.current_device(),
)
```

**Sharding strategies:**

| Strategy | Memory Savings | Speed | When to Use |
|----------|---------------|-------|-------------|
| `FULL_SHARD` | ~63% | Slowest | Model doesn't fit otherwise |
| `SHARD_GRAD_OP` | Medium | Medium | Balance of memory and speed |
| `NO_SHARD` | None (same as DDP) | Fastest | Model fits in GPU memory |

**FSDP gotchas:**
- Never use `always_wrap_policy` — it wraps every layer individually, killing performance
- Use transformer-specific wrap policies that wrap at the block/layer level
- CPU offload saves ~29% memory but is ~26x slower — only use as last resort
- FSDP checkpointing requires `FSDP.full_state_dict()` or `FSDP.sharded_state_dict()` — can't just call `.state_dict()` directly

## Multi-Node Training

Jobs requesting 4+ GPUs may span multiple nodes. rv handles the srun + torchrun coordination.

```bash
# 8 GPUs across 2 nodes (4 per node on a100)
rv run -g 8 -t a100 -- torchrun --nproc_per_node=4 train.py
```

rv automatically sets:
- `MASTER_ADDR` and `MASTER_PORT` for cross-node communication
- Per-node log files: `rv-job-{id}.node{N}.{out,err}`

**Multi-node considerations:**
- A100 (80GB) nodes have InfiniBand and NVLink — best for multi-node
- `rv logs` shows merged view with `[node0]`, `[node1]` prefixes
- `rv logs --node 1` to filter to a specific node
- `rv ssh --node 1` to attach to a specific node
- `rv gpu --node 1` for per-node nvidia-smi

**When NOT to go multi-node:**
- Inference with `device_map="auto"` — only works within one node. Use `--single-node`
- Jobs that don't use distributed training (no torchrun/DDP/FSDP)
- When communication overhead exceeds compute benefit (small models)

## Mixed Precision

Use BF16 on A100/H200 (compute capability >= 8.0). Use FP16 + GradScaler on older GPUs (V100, A6000, RTX 3090).

### BF16 (A100/H200)

```python
from torch.amp import autocast

with autocast("cuda", dtype=torch.bfloat16):
    output = model(input)
    loss = criterion(output, target)

loss.backward()
optimizer.step()
```

BF16 has the same exponent range as FP32, so no GradScaler needed.

### FP16 (older GPUs)

```python
from torch.amp import autocast, GradScaler

scaler = GradScaler("cuda")

with autocast("cuda", dtype=torch.float16):
    output = model(input)
    loss = criterion(output, target)

scaler.scale(loss).backward()
scaler.step(optimizer)
scaler.update()
```

FP16 has a narrower range — GradScaler prevents underflow in gradients.

### With FSDP

```python
from torch.distributed.fsdp import MixedPrecision

mp_policy = MixedPrecision(
    param_dtype=torch.bfloat16,
    reduce_dtype=torch.bfloat16,
    buffer_dtype=torch.bfloat16,
)

model = FSDP(model, mixed_precision=mp_policy, ...)
```

## Checkpointing

### Basic checkpoint (single GPU or DDP)

```python
import os, torch

checkpoint_dir = os.environ["RV_CHECKPOINT_DIR"]

# Save — use model.module for DDP
state = {
    "model": model.module.state_dict() if hasattr(model, "module") else model.state_dict(),
    "optimizer": optimizer.state_dict(),
    "epoch": epoch,
    "rng_state": torch.random.get_rng_state(),
    "cuda_rng_state": torch.cuda.get_rng_state(),
}
torch.save(state, os.path.join(checkpoint_dir, "latest.pt"))

# Load
ckpt = torch.load(os.path.join(checkpoint_dir, "latest.pt"), map_location="cpu", weights_only=False)
model.load_state_dict(ckpt["model"])
optimizer.load_state_dict(ckpt["optimizer"])
```

### Checkpoint-restart with SIGUSR1

For long training runs that use rv's checkpoint-restart feature:

```python
import signal, os, torch

checkpoint_dir = os.environ["RV_CHECKPOINT_DIR"]
should_stop = False

def handle_preempt(signum, frame):
    global should_stop
    should_stop = True

signal.signal(signal.SIGUSR1, handle_preempt)

# Resume
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
        break  # rv auto-resubmits
```

### FSDP checkpointing

```python
from torch.distributed.fsdp import FullStateDictConfig, StateDictType

# Full state dict (gathers to rank 0 — needs enough CPU memory)
save_policy = FullStateDictConfig(offload_to_cpu=True, rank0_only=True)
with FSDP.state_dict_type(model, StateDictType.FULL_STATE_DICT, save_policy):
    state_dict = model.state_dict()
    if dist.get_rank() == 0:
        torch.save(state_dict, os.path.join(checkpoint_dir, "latest.pt"))
```

### Naming for cross-run resume

Using the same `--name` shares the checkpoint directory:

```bash
# First run
rv run -g 4 -t a100 --name "llama-finetune" python train.py

# Resume after failure or preemption — same checkpoint dir
rv run -g 4 -t a100 --name "llama-finetune" python train.py
```

## Inference

### Single model, multiple GPUs (tensor parallel via device_map)

```bash
rv run -g 4 -t a100 --single-node python generate.py
```

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3-70B",
    device_map="auto",        # auto-shard across available GPUs
    torch_dtype=torch.bfloat16,
)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3-70B")
```

Use `--single-node` because `device_map="auto"` cannot shard across nodes.

### vLLM serving

```bash
rv run -g 2 -t a100 --single-node python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3-8B --tensor-parallel-size 2
```

Then forward the port: `rv forward --auto` or `rv forward 8000`.

## RLHF / GRPO

RLHF requires ~4x model size in memory (actor + critic + reward + reference models).

**Key considerations:**
- Reference model must be frozen (`requires_grad_(False)`)
- OpenRLHF needs Gloo backend for CPU reward aggregation
- GRPO: group relative policy optimization — simpler than PPO, no separate critic

```bash
# Example: OpenRLHF
rv run -g 8 -t a100 -- torchrun --nproc_per_node=4 \
    -m openrlhf.cli.train_ppo \
    --pretrain meta-llama/Llama-3-8B \
    --reward_pretrain meta-llama/Llama-3-8B-reward
```

## Process Groups

| Backend | Used For | Notes |
|---------|----------|-------|
| NCCL | GPU tensor communication | Default for DDP/FSDP. Required for GPU training |
| Gloo | CPU tensor communication | Used by some RLHF frameworks for reward aggregation |

**Wrong backend = silent hang.** If your job hangs during communication:
- GPU ops must use NCCL
- CPU ops must use Gloo
- Some frameworks need both: `dist.init_process_group(backend="nccl")` for main training, explicit Gloo groups for CPU operations

## Activation Checkpointing

Trade compute for memory — recompute activations during backward pass instead of storing them.

```python
from torch.utils.checkpoint import checkpoint

# Wrap expensive layers
class MyTransformerBlock(nn.Module):
    def forward(self, x):
        return checkpoint(self._forward, x, use_reentrant=False)

    def _forward(self, x):
        # actual forward logic
        ...
```

With FSDP:
```python
from torch.distributed.fsdp.wrap import transformer_auto_wrap_policy
from torch.distributed.algorithms._checkpoint.checkpoint_wrapper import (
    checkpoint_wrapper,
    apply_activation_checkpointing,
)

apply_activation_checkpointing(
    model,
    checkpoint_wrapper_fn=checkpoint_wrapper,
    check_fn=lambda module: isinstance(module, TransformerBlock),
)
```
