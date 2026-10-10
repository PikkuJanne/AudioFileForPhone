#!/usr/bin/env python3
"""Read-only technical public v1.0.0 verification; Python 3.9+ standard library.

Does NOT publish, fetch/checkout Git refs, modify the repository, or certify human
listening evidence. Downloads only to a temporary directory. Missing data fails.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

REPO = "PikkuJanne/AudioFileForPhone"
TAG = "v1.0.0"
ZIP_NAME = "AudioFileForPhone-v1.0.0.zip"
MANIFEST_NAME = "release-manifest.json"
SUMS_NAME = "SHA256SUMS.txt"
MAX_BYTES = 64 * 1024 * 1024
MAX_JSON = 2 * 1024 * 1024

class VerificationError(RuntimeError):
    """An unmet check, not a successful offline result."""

def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def valid_hex(value: object, length: int) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-fA-F]{%d}" % length, value) is not None

def expected_remote(url: str) -> bool:
    # No user tokens or passwords may occur in accepted HTTPS origins.
    match = re.fullmatch(
        r"(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)"
        r"PikkuJanne/AudioFileForPhone(?:\.git)?/?", url, re.IGNORECASE)
    return match is not None

def safe_member(name: str) -> bool:
    if not name or "\\" in name or ":" in name or "\x00" in name or name.startswith("/"):
        return False
    parts = name.split("/")
    reserved = {"con", "prn", "aux", "nul", "conin$", "conout$"}
    reserved.update("com" + str(n) for n in range(1, 10))
    reserved.update("lpt" + str(n) for n in range(1, 10))
    return all(p not in ("", ".", "..") and not p.endswith((" ", "."))
               and p.split(".", 1)[0].casefold() not in reserved
               and not any(ord(c) < 32 or c in '<>"|?*' for c in p)
               for p in parts)

def parse_ref(text: str, ref: str) -> str:
    matches = []
    for line in text.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1] == ref and valid_hex(fields[0], 40):
            matches.append(fields[0].lower())
    require(len(matches) == 1, "Missing, ambiguous or invalid live Git ref: " + ref)
    return matches[0]

def parse_sums(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r"([0-9a-fA-F]{64}) [ *](.+)", line)
        require(match is not None, "Invalid SHA256SUMS line.")
        assert match is not None
        name = match.group(2)
        require(name in (ZIP_NAME, MANIFEST_NAME), "Unexpected checksum entry.")
        require(name not in values, "Duplicate checksum entry.")
        values[name] = match.group(1).lower()
    require(set(values) == {ZIP_NAME, MANIFEST_NAME}, "Checksum file must list exactly ZIP and manifest.")
    return values

def check_candidate(candidate: dict) -> None:
    require(candidate.get("schema_version") == 1, "Unsupported candidate schema.")
    require(candidate.get("repository") == REPO and candidate.get("tag") == TAG, "Wrong candidate repository/tag.")
    for name, expected in (("zip_name", ZIP_NAME), ("manifest_name", MANIFEST_NAME), ("checksums_name", SUMS_NAME)):
        require(candidate.get(name) == expected, "Unexpected candidate asset name: " + name)
    for key, length in (("release_commit", 40), ("zip_sha256", 64), ("manifest_sha256", 64)):
        require(valid_hex(candidate.get(key), length), "Missing/placeholder candidate value: " + key)
    require(bool(candidate.get("release_authorization_reference")), "No recorded release authorization reference.")
    for key in ("automated_evidence", "windows_evidence", "phone_evidence"):
        require(isinstance(candidate.get(key), list) and bool(candidate[key]), "No evidence references: " + key)


def check_manifest(manifest: dict, candidate: dict) -> dict[str, str]:
    require(manifest.get("schema_version") == 1, "Unsupported release manifest schema.")
    require(manifest.get("repository") == REPO and manifest.get("tag") == TAG, "Manifest identity mismatch.")
    require(manifest.get("release_commit", "").lower() == candidate["release_commit"].lower(), "Manifest source mismatch.")
    z = manifest.get("zip", {})
    require(z.get("name") == ZIP_NAME and z.get("sha256", "").lower() == candidate["zip_sha256"].lower(), "Manifest ZIP mismatch.")
    files = manifest.get("files")
    require(isinstance(files, dict) and bool(files), "Missing package-member inventory.")
    assert isinstance(files, dict)
    require({"AudioFileForPhone.ps1", "AudioFileForPhone.bat", "README.md", "LICENSE"}.issubset(files), "Required entry points/docs/license missing.")
    require(len(files) <= 1024, "Unreasonable package-member count.")
    folded: set[str] = set()
    normalized: dict[str, str] = {}
    for name, sha in files.items():
        require(safe_member(name) and valid_hex(sha, 64), "Unsafe member path or missing member digest.")
        require(name.casefold() not in folded, "Case-colliding package members.")
        folded.add(name.casefold())
        lower = name.lower()
        require(not lower.startswith((".git/", "docs/codex-v1/")), "Development/private state in distributable.")
        require(PurePosixPath(lower).name not in ("ffmpeg.exe", "ffprobe.exe"), "FFmpeg binaries must remain external.")
        normalized[name] = sha.lower()
    names = {name.casefold() for name in normalized}
    for name in normalized:
        parents = PurePosixPath(name).parents
        require(not any(str(parent).casefold() in names for parent in parents if str(parent) != "."),
                "A package member is also used as a directory.")
    return normalized


def check_zip(path: Path, expected: dict[str, str]) -> None:
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        require(len(entries) <= 2048, "Unreasonable ZIP size/inventory.")
        seen: set[str] = set()
        actual: dict[str, str] = {}
        total = 0
        for entry in entries:
            name = entry.filename[:-1] if entry.is_dir() else entry.filename
            require(safe_member(name), "Unsafe ZIP member path.")
            require(entry.filename.casefold() not in seen, "Duplicate/case-colliding ZIP member.")
            seen.add(entry.filename.casefold())
            require(not stat.S_ISLNK(entry.external_attr >> 16), "ZIP symlink not allowed.")
            require(not entry.flag_bits & 1, "Encrypted ZIP member not allowed.")
            if entry.is_dir():
                require(any(member.startswith(name + "/") for member in expected), "Unexpected empty ZIP directory.")
                continue
            require(name in expected, "ZIP contains a member outside the approved allowlist.")
            total += entry.file_size
            require(total <= MAX_BYTES, "Decompressed package exceeds the verification bound.")
            # Stream decompression; bounds apply to observed bytes as well as headers.
            h = hashlib.sha256()
            read_count = 0
            with archive.open(entry) as stream:
                while True:
                    chunk = stream.read(1024 * 1024)
                    if not chunk:
                        break
                    read_count += len(chunk)
                    require(read_count <= entry.file_size and read_count <= MAX_BYTES, "Invalid ZIP member length.")
                    h.update(chunk)
            require(read_count == entry.file_size, "ZIP member length mismatch.")
            actual[name] = h.hexdigest()
        require(actual == expected, "ZIP member hashes/inventory differ from approved manifest.")


def git(root: Path, *arguments: str) -> str:
    env = dict(os.environ)
    env["GIT_TERMINAL_PROMPT"] = "0"
    result = subprocess.run(
        ["git", "--no-optional-locks", "-C", str(root), *arguments],
        capture_output=True, text=True, encoding="utf-8", errors="replace", env=env, timeout=60)
    # Do not include raw command output that might disclose a token-bearing remote.
    require(result.returncode == 0, "Git read failed; inspect local/ref/auth state separately.")
    return result.stdout


def check_git(root: Path, candidate: dict) -> dict:
    for args in (("remote", "get-url", "--all", "origin"), ("remote", "get-url", "--push", "--all", "origin")):
        urls = git(root, *args).splitlines()
        require(len(urls) == 1 and expected_remote(urls[0]), "Wrong/multiple origin fetch or push URLs.")
    require(git(root, "symbolic-ref", "--quiet", "--short", "HEAD").strip() == "main", "Final checkout must be on main.")
    require(not git(root, "status", "--porcelain=v1", "--untracked-files=all").strip(), "Final worktree is dirty/untracked.")
    head = git(root, "rev-parse", "HEAD").strip().lower()
    require(valid_hex(head, 40), "Invalid local HEAD.")
    live = parse_ref(git(root, "ls-remote", "--exit-code", "origin", "refs/heads/main"), "refs/heads/main")
    require(head == live, "Local main differs from live main.")
    c = candidate["release_commit"].lower()
    tag_text = git(root, "ls-remote", "origin", "refs/tags/v1.0.0", "refs/tags/v1.0.0^{}")
    # Require an annotated tag and compare its peeled commit, not its tag-object ID.
    tag_object = parse_ref(tag_text, "refs/tags/v1.0.0")
    require(parse_ref(tag_text, "refs/tags/v1.0.0^{}") == c, "Tag target differs from frozen C.")
    require(tag_object != c, "Expected an annotated tag object.")
    git(root, "merge-base", "--is-ancestor", c, head)
    changed = git(root, "diff", "--name-only", "-z", c, head).split("\x00")
    require(all(not p or p.startswith("docs/codex-v1/") for p in changed), "Non-evidence files changed after C; frozen payload drift.")
    return {"final_main_commit": head, "live_main_commit": live, "release_commit": c}


def allowed_https(url: str) -> bool:
    p = urllib.parse.urlsplit(url)
    return p.scheme == "https" and p.username is None and p.password is None and p.port in (None, 443) and (
        p.hostname in ("github.com", "api.github.com") or
        bool(p.hostname and p.hostname.endswith(".githubusercontent.com")))

class RestrictedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        require(allowed_https(newurl), "Download redirect left the allowed HTTPS GitHub hosts.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_bytes(url: str, limit: int) -> bytes:
    require(allowed_https(url), "Unexpected non-GitHub or non-HTTPS URL.")
    # No Authorization header, token environment or netrc integration is used.
    request = urllib.request.Request(url, headers={"User-Agent": "AudioFileForPhone-release-verifier/1.0"})
    opener = urllib.request.build_opener(RestrictedRedirect())
    with opener.open(request, timeout=45) as response:
        require(response.status == 200, "Public HTTP response was not successful.")
        data = response.read(limit + 1)
    require(len(data) <= limit, "HTTP response exceeds size bound.")
    return data


def api(path: str):
    data = fetch_bytes("https://api.github.com/repos/" + REPO + path, MAX_JSON)
    return json.loads(data.decode("utf-8"))


def check_public(candidate: dict) -> dict:
    repo = api("")
    require(repo.get("full_name", "").casefold() == REPO.casefold(), "Public repository identity mismatch.")
    require(repo.get("private") is False and repo.get("visibility") == "public", "Repository is not publicly accessible.")
    require(repo.get("default_branch") == "main", "Unexpected public default branch.")
    release = api("/releases/tags/" + TAG)
    require(release.get("tag_name") == TAG and release.get("draft") is False and
            release.get("prerelease") is False and bool(release.get("published_at")), "v1.0.0 is not a normal published release.")
    all_releases = api("/releases?per_page=100")
    require(isinstance(all_releases, list), "Invalid public release listing.")
    public = [r for r in all_releases if r.get("draft") is False]
    require(len(public) == 1 and public[0].get("id") == release.get("id"), "Unexpected additional public releases; reconcile scope without deleting anything.")
    latest = api("/releases/latest")
    require(latest.get("id") == release.get("id"), "v1.0.0 is not the latest normal release.")
    assets = release.get("assets", [])
    require(isinstance(assets, list) and len(assets) == 3, "Expected exactly the three approved release assets.")
    names = [a.get("name") for a in assets]
    require(set(names) == {ZIP_NAME, MANIFEST_NAME, SUMS_NAME}, "Unexpected/missing/duplicate release assets.")
    downloaded = {}
    base = "https://github.com/" + REPO + "/releases/download/" + TAG + "/"
    for asset in assets:
        name = asset["name"]
        require(asset.get("state") == "uploaded" and isinstance(asset.get("size"), int) and asset["size"] > 0,
                "Asset upload incomplete or empty.")
        url = asset.get("browser_download_url", "")
        require(url == base + urllib.parse.quote(name), "Unexpected asset download origin/path.")
        data = fetch_bytes(url, MAX_BYTES if name == ZIP_NAME else MAX_JSON)
        require(len(data) == asset["size"], "Downloaded asset size mismatch.")
        downloaded[name] = data
    require(digest(downloaded[ZIP_NAME]) == candidate["zip_sha256"].lower(), "Public ZIP hash differs from approval.")
    require(digest(downloaded[MANIFEST_NAME]) == candidate["manifest_sha256"].lower(), "Public manifest hash differs from approval.")
    sums = parse_sums(downloaded[SUMS_NAME].decode("utf-8-sig"))
    for name in (ZIP_NAME, MANIFEST_NAME):
        require(sums[name] == digest(downloaded[name]), "Published checksum mismatch.")
    manifest = json.loads(downloaded[MANIFEST_NAME].decode("utf-8"))
    members = check_manifest(manifest, candidate)
    with tempfile.TemporaryDirectory(prefix="AudioFileForPhone-public-verify-") as temporary:
        zip_path = Path(temporary) / ZIP_NAME
        zip_path.write_bytes(downloaded[ZIP_NAME])
        check_zip(zip_path, members)
    return {"release_url": release.get("html_url"), "published_at": release["published_at"],
            "zip_sha256": digest(downloaded[ZIP_NAME]), "manifest_sha256": digest(downloaded[MANIFEST_NAME]),
            "package_members_verified": len(members), "public_downloads": "verified_without_authorization_header"}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-path", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        candidate = json.loads(args.candidate.read_text(encoding="utf-8-sig"))
        check_candidate(candidate)
        result = {"technical_status": "pass", **check_git(args.repo_path.resolve(), candidate), **check_public(candidate),
                  "verified_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                  "scope": "Public state/bytes and final Git sync only. Independently audit required tests and actual Windows/phone evidence."}
        print(json.dumps(result, indent=2))
        return 0
    except (VerificationError, OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError, zipfile.BadZipFile) as exc:
        print(json.dumps({"technical_status": "fail", "reason": str(exc)}, indent=2), file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
