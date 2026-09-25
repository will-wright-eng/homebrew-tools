#!/usr/bin/env python3
"""Bump the formulae that `brew livecheck --json` reports as outdated."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

PYPI_FILES_HOST = "files.pythonhosted.org"
PYTHON_VIRTUALENV = "Language::Python::Virtualenv"

# Two-space indentation matches only the formula's own stanzas, not those in
# `resource` or `livecheck` blocks.
STABLE_URL = re.compile(r'^(  url ")([^"]+)(")', re.MULTILINE)
STABLE_SHA256 = re.compile(r'^(  sha256 ")([0-9a-f]{64})(")', re.MULTILINE)


@dataclass
class Bump:
    formula: str
    current: str
    latest: str
    url: str
    python_resources: bool


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "homebrew-tools-livecheck"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def resolve_pypi(url: str, current: str, latest: str) -> tuple[str, str, str]:
    filename = Path(urlparse(url).path).name
    target = filename.replace(current, latest)
    project = filename.split("-", 1)[0]
    release = json.loads(fetch(f"https://pypi.org/pypi/{project}/{latest}/json"))
    for artifact in release["urls"]:
        if artifact["filename"] == target:
            return artifact["url"], artifact["digests"]["sha256"], release["info"]["name"]
    raise ValueError(f"PyPI {project} {latest} has no file named {target}")


def resolve_archive(url: str, current: str, latest: str) -> tuple[str, str]:
    new_url = url.replace(current, latest)
    if new_url == url:
        raise ValueError(f"version {current} does not appear in {url}")
    return new_url, hashlib.sha256(fetch(new_url)).hexdigest()


def replace_first(pattern: re.Pattern, value: str, text: str) -> str:
    return pattern.sub(lambda m: m[1] + value + m[3], text, count=1)


def bump(formula_dir: Path, tap: str, name: str, current: str, latest: str) -> Bump:
    path = formula_dir / f"{name}.rb"
    original = path.read_text()
    match = STABLE_URL.search(original)
    if not match or not STABLE_SHA256.search(original):
        raise ValueError(f"{path} has no top-level url and sha256")

    url = match[2]
    package_name = None
    if urlparse(url).hostname == PYPI_FILES_HOST:
        new_url, sha256, package_name = resolve_pypi(url, current, latest)
    else:
        new_url, sha256 = resolve_archive(url, current, latest)

    text = replace_first(STABLE_URL, new_url, original)
    text = replace_first(STABLE_SHA256, sha256, text)
    path.write_text(text)

    python_resources = PYTHON_VIRTUALENV in text
    if python_resources:
        try:
            subprocess.run(
                [
                    "brew", "update-python-resources",
                    "--install-dependencies",
                    "--ignore-main-package-cooldown",
                    f"--package-name={package_name or name}",
                    f"--version={latest}",
                    f"{tap}/{name}",
                ],
                check=True,
            )
        except subprocess.CalledProcessError:
            path.write_text(original)
            raise

    return Bump(name, current, latest, new_url, python_resources)


def pr_title(bumps: list[Bump]) -> str:
    scope = ",".join(b.formula for b in bumps)
    changes = ", ".join(f"{b.formula} to {b.latest}" for b in bumps)
    return f"chore({scope}): bump {changes}"


def pr_body(bumps: list[Bump]) -> str:
    rows = "\n".join(
        f"| `{b.formula}` | {b.current} | {b.latest} | {b.url} |" for b in bumps
    )
    body = (
        "`brew livecheck` found newer upstream releases.\n\n"
        "| Formula | Current | Latest | Source |\n"
        "| ------- | ------- | ------ | ------ |\n"
        f"{rows}\n"
    )
    regenerated = [f"`{b.formula}`" for b in bumps if b.python_resources]
    if regenerated:
        body += (
            f"\nPython resources for {', '.join(regenerated)} were regenerated with "
            "`brew update-python-resources`. Check for new build dependencies.\n"
        )
    return body


def write_outputs(bumps: list[Bump]) -> None:
    github_output = os.environ.get("GITHUB_OUTPUT")
    if not github_output:
        return
    with open(github_output, "a") as out:
        out.write(f"bumped={' '.join(b.formula for b in bumps)}\n")
        out.write(f"title={pr_title(bumps) if bumps else ''}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("livecheck_json", type=Path, help="output of `brew livecheck --json`")
    parser.add_argument("--formula-dir", type=Path, default=Path("Formula"))
    parser.add_argument("--tap", default="will-wright-eng/tools")
    parser.add_argument("--pr-body", type=Path, help="write the pull request body here")
    args = parser.parse_args()

    bumps: list[Bump] = []
    errors: list[str] = []
    for entry in json.loads(args.livecheck_json.read_text()):
        name = entry["formula"].rsplit("/", 1)[-1]
        if entry.get("status") == "error":
            errors.append(f"{name}: livecheck failed: {'; '.join(entry.get('messages', []))}")
            continue
        version = entry.get("version", {})
        if not version.get("outdated"):
            continue
        try:
            bumps.append(bump(args.formula_dir, args.tap, name, version["current"], version["latest"]))
            print(f"{name}: {version['current']} -> {version['latest']}")
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
            errors.append(f"{name}: bump to {version['latest']} failed: {error}")

    write_outputs(bumps)
    if args.pr_body and bumps:
        args.pr_body.write_text(pr_body(bumps))
    for error in errors:
        print(f"::error::{error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
