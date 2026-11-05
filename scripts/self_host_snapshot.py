#!/usr/bin/env python3
"""Encrypted cold snapshots and fresh-target restore for disposable RAD self-host tests.

Physical PostgreSQL snapshots require the exact same image and architecture.
No cloud target, dev-stack target, volume overwrite, teardown or plaintext dump.
Production scheduling/offsite policy needs a separately reviewed operator wrapper.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import tarfile
from pathlib import Path

try:
    from .self_host_stack import compose, run, save
except ImportError:
    from self_host_stack import compose, run, save

VOLUMES = ("db-data", "db-config", "storage-data")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def is_posix_gpg(binary: str) -> bool:
    """True for an MSYS2/Git-for-Windows gpg, which parses POSIX paths only."""
    location = Path(binary).as_posix().lower()
    return location.startswith(("/usr/", "/bin/")) or "/usr/bin/" in location


def to_posix_drive_path(path: str) -> str:
    """Rewrite `D:\\dir\\file` as `/d/dir/file`; leave a POSIX path untouched.

    Pure string logic so it is testable on any platform, independent of the
    host's own path semantics.
    """
    drive, _, remainder = path.partition(":")
    if len(drive) != 1 or not drive.isalpha() or not remainder:
        return path
    return "/" + drive.lower() + remainder.replace("\\", "/")


def gpg_path(binary: str, path: Path) -> str:
    """Render a path the way the selected gpg build will actually parse it.

    A POSIX gpg (MSYS2/Git for Windows) cannot read a `D:\\...` argument: it
    treats it as relative, prepends the cwd and fails to create its homedir or
    read the passphrase file. Hand such builds an `/d/...` path instead.
    """
    resolved = str(path.resolve())
    return to_posix_drive_path(resolved) if is_posix_gpg(binary) else resolved


def gpg_command(binary: str, key_file: Path, decrypt: bool = False) -> list[str]:
    if not key_file.is_file() or key_file.stat().st_size < 32:
        raise ValueError("private high-entropy snapshot passphrase reference required")
    state = key_file.resolve().parent / ".rad-snapshot-gnupg"
    state.mkdir(mode=0o700, exist_ok=True)
    return [
        binary,
        "--no-options",
        "--homedir",
        gpg_path(binary, state),
        "--batch",
        "--yes",
        "--no-tty",
        "--pinentry-mode",
        "loopback",
        "--passphrase-file",
        gpg_path(binary, key_file),
        *(
            ["--decrypt"]
            if decrypt
            else ["--symmetric", "--cipher-algo", "AES256", "--compress-algo", "none"]
        ),
    ]


def identity(root: Path) -> tuple[dict, dict]:
    compose(root, "ps")
    meta = json.loads((root / "RAD_ISOLATED_INSTALL.json").read_text("utf8"))
    model = json.loads((root / "compose.rad.json").read_text("utf8"))
    image = model["services"]["db"]["image"]
    if "@sha256:" not in image:
        raise ValueError("pin all image digests before snapshot/restore")
    return meta, model


def volume_command(meta: dict, image: str, volume: str, write: bool) -> list[str]:
    return [
        "docker",
        "run",
        "--rm",
        "-i",
        "--network",
        "none",
        "--read-only",
        "--cap-drop",
        "ALL",
        "--cap-add",
        "DAC_OVERRIDE",
        *(["--cap-add", "CHOWN", "--cap-add", "FOWNER"] if write else []),
        "--mount",
        f"type=volume,src={meta['project']}_{volume},dst=/snapshot"
        + ("" if write else ",readonly"),
        "--entrypoint",
        "tar",
        image,
        "-C",
        "/snapshot",
        "-xpf" if write else "-cpf",
        "-",
        *([] if write else ["."]),
    ]


def encrypt_process(command: list[str], output: Path, encryption: list[str]) -> None:
    with output.open("xb") as target:
        producer = subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        consumer = subprocess.Popen(
            encryption, stdin=producer.stdout, stdout=target, stderr=subprocess.DEVNULL
        )
        producer.stdout.close()
        consumed, produced = consumer.wait(), producer.wait()
    if consumed or produced:
        raise RuntimeError(
            "encrypted volume snapshot failed; incomplete archive must not be accepted"
        )


def backup(root: Path, output: Path, key_file: Path, binary: str) -> dict:
    meta, model = identity(root)
    if output.exists() or output.resolve().is_relative_to(root.resolve()):
        raise ValueError("new external encrypted snapshot directory required")
    if key_file.resolve().is_relative_to(
        root.resolve()
    ) or key_file.resolve().is_relative_to(output.resolve()):
        raise ValueError("snapshot decryption key must be stored independently")
    encryption = gpg_command(binary, key_file)
    output.mkdir(parents=True)
    image = model["services"]["db"]["image"]
    # Stop only this explicitly owned Compose project. Cold capture includes
    # Auth, cron, Realtime, Storage and Edge writers, not merely API maintenance.
    run(compose(root, "stop", "--timeout", "60"))
    try:
        for volume in VOLUMES:
            encrypt_process(
                volume_command(meta, image, volume, False),
                output / (volume + ".tar.gpg"),
                encryption,
            )
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode="w") as archive:
            for name in (
                ".env",
                "compose.rad.json",
                "RAD_ISOLATED_INSTALL.json",
                "RAD_BUNDLE_MANIFEST.json",
                "IMAGE_DIGESTS.json",
            ):
                archive.add(root / name, arcname=name, recursive=False)
        encrypted = run(encryption, input=data.getvalue())
        (output / "configuration.tar.gpg").write_bytes(encrypted.stdout)
        receipt = {
            "status": "ENCRYPTED_COLD_SNAPSHOT_NOT_OFFSITE_OR_RESTORE_ACCEPTANCE",
            "source": meta,
            "postgres_image": image,
            "files": {p.name: digest(p) for p in output.glob("*.gpg")},
        }
        save(output / "SNAPSHOT.json", receipt)
    finally:
        run(compose(root, "up", "-d", "--wait", "--wait-timeout", "240"))
    return receipt


def restore(root: Path, snapshot: Path, key_file: Path, binary: str) -> dict:
    meta, model = identity(root)
    receipt = json.loads((snapshot / "SNAPSHOT.json").read_text("utf8"))
    if (
        receipt["source"]["project"] == meta["project"]
        or receipt["postgres_image"] != model["services"]["db"]["image"]
    ):
        raise ValueError("distinct fresh project and exact PostgreSQL image required")
    # Existing containers OR volumes cause refusal, even when stopped/empty.
    existing = run(
        [
            "docker",
            "ps",
            "-aq",
            "--filter",
            "label=com.docker.compose.project=" + meta["project"],
        ]
    ).stdout.strip()
    if existing:
        raise ValueError("restore refuses any target with existing containers")
    for volume in VOLUMES:
        name = meta["project"] + "_" + volume
        found = subprocess.run(
            ["docker", "volume", "inspect", name], capture_output=True
        )
        if found.returncode == 0:
            raise ValueError("restore refuses any pre-existing target volume")
    names = {v + ".tar.gpg" for v in VOLUMES} | {"configuration.tar.gpg"}
    if set(receipt["files"]) != names:
        raise ValueError("snapshot inventory mismatch")
    for name, expected in receipt["files"].items():
        if digest(snapshot / name) != expected:
            raise ValueError("snapshot checksum mismatch")
    decrypt = gpg_command(binary, key_file, True)
    # Authenticate every ciphertext before creating even one target volume.
    for name in names:
        checked = subprocess.run(
            [*decrypt, gpg_path(binary, snapshot / name)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if checked.returncode:
            raise ValueError("snapshot decryption/integrity verification failed")
    for volume in VOLUMES:
        run(
            [
                "docker",
                "volume",
                "create",
                "--label",
                "com.docker.compose.project=" + meta["project"],
                "--label",
                "com.docker.compose.volume=" + volume,
                meta["project"] + "_" + volume,
            ]
        )
        producer = subprocess.Popen(
            [*decrypt, gpg_path(binary, snapshot / (volume + ".tar.gpg"))],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        consumer = subprocess.Popen(
            volume_command(meta, receipt["postgres_image"], volume, True),
            stdin=producer.stdout,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        producer.stdout.close()
        consumed, produced = consumer.wait(), producer.wait()
        if consumed or produced:
            raise RuntimeError(
                "fresh-target restore failed; do not start incomplete target"
            )
    # DB role passwords/JWT/Vault keys must match the captured cluster. Preserve
    # new loopback URL/port routing but restore its original service credentials.
    plain = run([*decrypt, gpg_path(binary, snapshot / "configuration.tar.gpg")]).stdout
    with tarfile.open(fileobj=io.BytesIO(plain)) as archive:
        source_env = archive.extractfile(".env").read().decode("utf8")
    current = dict(
        line.split("=", 1)
        for line in (root / ".env").read_text("utf8").splitlines()
        if "=" in line
    )
    original = dict(
        line.split("=", 1) for line in source_env.splitlines() if "=" in line
    )
    for name in (
        "SUPABASE_PUBLIC_URL",
        "API_EXTERNAL_URL",
        "SITE_URL",
        "ADDITIONAL_REDIRECT_URLS",
    ):
        original[name] = current[name]
    (root / ".env").write_text(
        "".join(f"{k}={v}\n" for k, v in original.items()), encoding="utf8"
    )
    (root / ".env").chmod(0o600)
    result = {
        "status": "RESTORED_FRESH_NOT_APPLICATION_ACCEPTANCE",
        "target": meta,
        "snapshot_files": receipt["files"],
    }
    save(root / "RESTORE_RECEIPT.json", result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("backup", "restore"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--key-file", type=Path, required=True)
    parser.add_argument("--gpg", default=shutil.which("gpg"))
    args = parser.parse_args()
    if not args.gpg:
        raise SystemExit(
            "GnuPG 2.x required; install through the operating system package manager"
        )
    operation = backup if args.command == "backup" else restore
    print(
        json.dumps(
            operation(
                args.root.resolve(),
                args.snapshot.resolve(),
                args.key_file.resolve(),
                args.gpg,
            )
        )
    )


if __name__ == "__main__":
    main()
