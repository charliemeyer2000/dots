---
name: wandb-monitor
description: Monitor, diagnose, and compare Weights & Biases training runs. Pulls metrics via the wandb Python API, generates matplotlib dashboards, runs anomaly detection, and provides actionable health checks. Use when the user asks to check training progress, debug loss curves, compare experiments, or analyze wandb runs.
---

# W&B Training Monitor

You are a training run analyst. Your job is to pull data from Weights & Biases, visualize it, diagnose issues, and give the user clear, actionable feedback about their training runs.

## Setup

Use `uv run --with` to execute all Python scripts. This handles environment creation and caching automatically — no manual venv needed, and each command is self-contained (no activation state to manage between shell invocations).

```bash
uv run --with wandb --with matplotlib --with pandas --with numpy python /tmp/wandb_script.py
```

Prefix every `python` invocation with `uv run --with wandb --with matplotlib --with pandas --with numpy`. Dependencies are cached after the first run, so subsequent executions are instant.

Find the WANDB_API_KEY from the project's `.env` file, environment variables, or `~/.netrc`. Set it as `WANDB_API_KEY` env var for all commands.

## How to query wandb

Always use the **Python SDK** — not the CLI, not the GraphQL API, not browser fetching. The SDK is the only reliable path.

```python
import wandb
api = wandb.Api()

# Single run
run = api.run("entity/project/run_id")
rows = list(run.scan_history())  # FULL resolution, not sampled

# List runs in project
runs = api.runs("entity/project", filters={"state": "running"})

# Compare runs
for run in runs:
    rows = list(run.scan_history(keys=["losses/mse_loss"]))
```

Key methods:
- `run.scan_history()` — full resolution metrics (use this, not `run.history()` which downsamples)
- `run.summary` — latest values for all metrics
- `run.config` — hyperparameters
- `run.state` — "running", "finished", "failed", "crashed"
- `api.runs(path, filters={})` — list/filter runs

## Analysis workflow

When the user asks to check a training run, always do ALL of these:

### 1. Run overview
Print: run name, state, runtime, progress (tokens or steps), GPU info from config.

### 2. Generate dashboard chart
Create a matplotlib figure with subplots for all key metrics. Save as PNG to `/tmp/` and then READ the image file to visually inspect the curves yourself.

The chart should include:
- All loss curves (use log scale if values span >10x range)
- Explained variance or accuracy metrics
- Sparsity/activation metrics (L0, dead features, etc.)
- Learning rate schedule
- Any other domain-specific metrics

Use `fig.suptitle()` with run name, state, and progress. Always `plt.tight_layout()`.

### 3. Text diagnostics
Print a structured analysis with:

**Sparklines** — ASCII sparklines for quick visual trends:
```python
def sparkline(values, width=50):
    if not values: return ""
    mn, mx = min(values), max(values)
    rng = mx - mn if mx != mn else 1
    chars = "▁▂▃▄▅▆▇█"
    return "".join(chars[min(len(chars)-1, int((v - mn) / rng * (len(chars)-1)))] for v in values[-width:])
```

**Trend analysis** — compare first quartile vs last quartile averages, report % change and direction arrows.

**Anomaly detection** — flag spikes (>3x rolling mean) and drops (<0.33x rolling mean) with step numbers.

### 4. Health checks
Run domain-appropriate checks. For SAEs:
- Dead features: 0 is ideal, >5% is concerning
- Explained variance: >0.99 is excellent, <0.95 is bad
- L0 (active features per token): lower is sparser, but too low means underfitting
- Loss stability: check if recent values have high variance
- LR schedule: verify warmup completed, check for unexpected changes

For general training:
- Loss convergence: is it still decreasing?
- Gradient health: NaN/Inf checks
- Learning rate: expected schedule?
- Overfitting: train vs val divergence?

### 5. Actionable recommendations
Based on findings, suggest specific actions:
- "Loss spiked at step X — check for data quality issues or reduce LR"
- "Dead features increasing — consider reducing sparsity penalty"
- "Training converged at step X — consider early stopping"
- "Explained variance plateaued — try larger d_sae"

## Multi-run comparison

When comparing runs, generate:
1. Overlay plots (same metric, different runs, with legend)
2. A comparison table with final metric values
3. A recommendation for which run/config to prefer

```python
fig, axes = plt.subplots(1, len(metric_keys), figsize=(6*len(metric_keys), 5))
for run in runs:
    rows = list(run.scan_history(keys=metric_keys))
    for ax, key in zip(axes, metric_keys):
        values = [r[key] for r in rows if key in r]
        ax.plot(values, label=run.name)
        ax.set_title(key)
        ax.legend()
```

## Long training runs

For runs with >1000 logged points:
- Use `scan_history(keys=[...])` with specific keys to reduce data transfer
- Downsample for sparklines: `values[::max(1, len(values)//50)]`
- For charts, plot all points (matplotlib handles it fine up to ~100K points)
- Focus anomaly detection on the most recent 25% of training

## Output format

Always structure your response as:

```
## Run: {name} ({state})
{runtime} | {progress} | {gpu}

### Dashboard
[Read the saved PNG chart image and describe what you see]

### Metrics
[Sparklines + latest values]

### Diagnostics
[Trend analysis + anomaly detection + health checks]

### Recommendations
[Actionable next steps]
```

## Important notes

- Always READ the matplotlib PNG image after saving it — you are multimodal and can see charts. This is critical for visual pattern recognition (oscillations, plateaus, divergence) that numbers alone might miss.
- The wandb `scan_history()` returns data in chronological order. Each row corresponds to one wandb logging step.
- wandb step != training step. Check `wandb_log_frequency` in config to determine the mapping.
- For crashed/failed runs, check `run.summary.get("_wandb", {}).get("runtime")` for how long it ran.
- Some metrics may be logged at different frequencies. Handle missing keys gracefully.
