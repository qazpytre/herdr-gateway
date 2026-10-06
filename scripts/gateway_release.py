#!/usr/bin/env python3
"""Generate the gateway feed from immutable release artifacts and archived builds."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import tomllib

REPOSITORY = "qazpytre/herdr-gateway"
TARGETS = ("macos-aarch64", "linux-x86_64")


def manifest(tag: str, artifacts: Path, previous: dict) -> dict:
    base = tomllib.loads(Path("Cargo.toml").read_text())["package"]["version"]
    match = re.fullmatch(rf"gateway-{re.escape(base)}-([0-9]+)", tag)
    if not match:
        raise ValueError(f"tag must be gateway-{base}-<numeric revision>")
    revision = int(match[1])
    identity = f"{base}-gateway.{revision}"
    if previous and previous.get("channel") != "gateway":
        raise ValueError("refusing non-gateway manifest history")
    if previous:
        def order(value):
            version, build = value.split("-gateway.")
            return tuple(map(int, version.split("."))), int(build)
        if order(identity) <= order(previous["version"]):
            raise ValueError("release must be newer than the published gateway feed")
    assets = {}
    for target in TARGETS:
        name = f"herdr-gateway-{target}"
        binary = artifacts / name
        assets[target] = {
            "url": f"https://github.com/{REPOSITORY}/releases/download/{tag}/{name}",
            "sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        }
    wire = Path("src/protocol/wire.rs").read_text()
    endpoint = Path("src/protocol/endpoint.rs").read_text()
    protocol = int(re.search(r"pub const PROTOCOL_VERSION: u32 = ([0-9]+);", wire)[1])
    generation = int(re.search(r"pub const ENDPOINT_PROTOCOL_GENERATION: u32 = ([0-9]+);", endpoint)[1])
    release = {
        "version": identity,
        "channel": "gateway",
        "protocol": protocol,
        "endpoint_generation": generation,
        "notes": f"Gateway fork {identity}. Includes the per-target SSH trust policy, fork updates, and automated SSH deployment.",
        "assets": assets,
    }
    history = dict(previous.get("releases", {}))
    if previous:
        history[previous["version"]] = {k: v for k, v in previous.items() if k != "releases"}
    history[identity] = release.copy()
    return {**release, "releases": history}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--previous", type=Path)
    args = parser.parse_args()
    previous = json.loads(args.previous.read_text()) if args.previous else {}
    result = manifest(args.tag, args.artifacts, previous)
    (args.artifacts / "latest.json").write_text(json.dumps(result, indent=2) + "\n")
    checksums = "".join(f"{asset['sha256']}  herdr-gateway-{target}\n" for target, asset in result["assets"].items())
    (args.artifacts / "SHA256SUMS").write_text(checksums)


if __name__ == "__main__":
    main()
