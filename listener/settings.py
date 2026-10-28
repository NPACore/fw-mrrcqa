"""
Where the TOML settings live (listener/config/, next to this file) and how to read them.
"""

import os

# CONFIG_DIR overridse the default
CONFIG_DIR = os.environ.get(
        "CONFIG_DIR",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "config"),
)


def load_toml(path):
    """Parse on TOML file into a dict. Raises if it is missing or malformed."""
    try:
        import tomllib
    except ImportError: # Python < 3.11
        import toml
        return toml.load(path)
    with open(path, "rb") as f:
        return tomllib.load(f)
