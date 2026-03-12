# Python Project Setup with uv

## Project Structure

```
myproject/
├── pyproject.toml          # Project metadata and dependencies
├── README.md
├── .python-version         # Pin Python version for uv
├── src/
│   └── myproject/
│       ├── __init__.py
│       ├── py.typed         # PEP 561 type marker
│       ├── core.py
│       └── utils.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_core.py
└── docs/
    └── index.md
```

## uv Commands

```bash
# Project setup
uv init myproject              # Create new project
uv init --lib myproject        # Create library project (src layout)

# Dependencies
uv add requests pydantic       # Add dependencies
uv add --dev pytest mypy ruff  # Add dev dependencies
uv remove requests             # Remove a dependency
uv sync                        # Install/sync all dependencies
uv lock                        # Update lockfile without installing

# Running
uv run pytest                  # Run command in project venv
uv run python script.py        # Run script in project venv
uv run --with httpx script.py  # Run with an extra ad-hoc dependency

# Scripts (standalone, no project needed)
uv run script.py               # Run a script with inline deps

# Tools (global CLI tools)
uv tool install ruff           # Install CLI tool globally
uv tool run black .            # Run tool without installing (like npx)

# Python version management
uv python install 3.12         # Install a Python version
uv python pin 3.12             # Pin version for project (.python-version)
uv python list                 # List available/installed versions
```

## pyproject.toml Configuration

```toml
[project]
name = "myproject"
version = "0.1.0"
description = "A Python project"
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "you@example.com"}
]
dependencies = [
    "requests>=2.31.0",
    "pydantic>=2.5.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "mypy>=1.7.0",
    "black>=23.11.0",
    "ruff>=0.1.6",
]

[project.scripts]
myproject = "myproject.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

# Tool configurations
[tool.black]
line-length = 100
target-version = ["py311"]

[tool.ruff]
line-length = 100
target-version = "py311"
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # pyflakes
    "I",   # isort
    "B",   # flake8-bugbear
    "C4",  # flake8-comprehensions
    "UP",  # pyupgrade
]

[tool.ruff.per-file-ignores]
"__init__.py" = ["F401"]

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[[tool.mypy.overrides]]
module = "third_party.*"
ignore_missing_imports = true

[tool.pytest.ini_options]
minversion = "7.0"
addopts = [
    "-ra",
    "--strict-markers",
    "--strict-config",
    "--cov=myproject",
    "--cov-report=term-missing",
]
testpaths = ["tests"]
pythonpath = ["src"]

[tool.coverage.run]
source = ["src"]
branch = true

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
]
```

## Inline Script Dependencies

For standalone scripts that don't need a full project:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "httpx",
#     "rich",
# ]
# ///

import httpx
from rich import print

response = httpx.get("https://api.example.com")
print(response.json())
```

Run with: `uv run script.py`

## Package __init__.py

```python
# src/myproject/__init__.py
"""MyProject - A Python package."""

from myproject.core import main_function, CoreClass
from myproject.utils import helper_function

__version__ = "0.1.0"
__all__ = ["main_function", "CoreClass", "helper_function"]
```

## Type Stub Files (py.typed)

```python
# src/myproject/py.typed
# Empty file — indicates package includes type hints (PEP 561)
```

## CLI Entry Points

```python
# src/myproject/cli.py
import sys
from typing import NoReturn

def main() -> NoReturn:
    """Main CLI entry point."""
    print("MyProject CLI")
    sys.exit(0)

if __name__ == "__main__":
    main()
```

## Building and Distribution

```bash
uv build                       # Build sdist + wheel
uv publish                     # Publish to PyPI
uv publish --index testpypi    # Publish to Test PyPI
```

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]

    steps:
    - uses: actions/checkout@v4
    - name: Install uv
      uses: astral-sh/setup-uv@v5

    - name: Set up Python
      run: uv python install ${{ matrix.python-version }}

    - name: Install dependencies
      run: uv sync --all-extras

    - name: Run tests
      run: uv run pytest --cov --cov-report=xml

    - name: Type check
      run: uv run mypy src

    - name: Lint
      run: |
        uv run black --check src tests
        uv run ruff check src tests
```
