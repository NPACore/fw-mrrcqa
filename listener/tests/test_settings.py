import os
import subprocess
import sys

LISTENER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


import settings


def test_config_dir_default_and_override():
    """CONFIG_DIR is listener/config unless the CONFIG_DIR env var says otherwise."""
    def config_dir(**env):
        e = {k: v for k, v in os.environ.items() if k != "CONFIG_DIR"}
        e.update(env)
        out = subprocess.run(
            [sys.executable, "-c", "import settings; print(settings.CONFIG_DIR)"],
            cwd=LISTENER, env=e, capture_output=True, text=True, check=True)
        return out.stdout.strip()

    assert config_dir() == os.path.join(LISTENER, "config")
    assert config_dir(CONFIG_DIR="/somewhere/else") == "/somewhere/else"


def test_load_toml_reads_shipped_shim_toml():
    """load_toml parses the real config/shim.toml (regexes and all)."""
    cfg = settings.load_toml(os.path.join(settings.CONFIG_DIR, "shim.toml"))
    assert len(cfg["scanner"]) >= 1
    assert all(s["id"] and s["shortname"] for s in cfg["scanner"])
