"""Secret-safe explicit adapter for tests on an owned loopback self-host install."""

from __future__ import annotations

import json
import os
from pathlib import Path

try:
    from .self_host_stack import compose, run
except ImportError:
    from self_host_stack import compose, run


def target_root() -> Path:
    root = Path(os.environ["RAD_SELF_HOST_TEST_ROOT"]).resolve(strict=True)
    compose(root, "ps")  # validate the explicit disposable identity
    return root


def load_target() -> tuple[str, str, str]:
    root = target_root()
    identity = json.loads((root / "RAD_ISOLATED_INSTALL.json").read_text("utf8"))
    result = run(compose(root, "ps", "--format", "json", "api-gw"))
    entries = [json.loads(line) for line in result.stdout.decode().splitlines() if line]
    if len(entries) != 1 or entries[0]["Project"] != identity["project"]:
        raise ValueError("owned isolated gateway required")
    publishers = entries[0].get("Publishers") or []
    if not any(
        p.get("URL") == "127.0.0.1" and p.get("PublishedPort") == identity["api_port"]
        for p in publishers
    ):
        raise ValueError("owned loopback gateway binding required")
    values = dict(
        line.split("=", 1)
        for line in (root / ".env").read_text("utf8").splitlines()
        if line and not line.startswith("#") and "=" in line
    )
    expected = f"http://127.0.0.1:{identity['api_port']}"
    if values["SUPABASE_PUBLIC_URL"] != expected:
        raise ValueError("non-loopback or wrong self-host acceptance URL")
    return expected, values["ANON_KEY"], values["SERVICE_ROLE_KEY"]
