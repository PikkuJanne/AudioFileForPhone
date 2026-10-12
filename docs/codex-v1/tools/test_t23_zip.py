#!/usr/bin/env python3
"""Exact local release ZIP smoke; Windows, Python standard library, test-only.

Creates one exclusive external workspace and retains its logs/media. Never changes
source/assets, downloads tools, uses Music for conversions, or kills processes.
Timeouts fail and retain the owned process/workspace for inspection. This is local
technical evidence, not phone acceptance, release authorization or publication.
"""
from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import time
import uuid
import zipfile
import zlib

MEMBERS = sorted(("AudioFileForPhone.ps1", "AudioFileForPhone.Helpers.ps1",
                  "AudioFileForPhone.bat", "README.md", "SUPPORT.md",
                  "CHANGELOG.md", "SECURITY.md", "LICENSE"))
ASSETS = ("AudioFileForPhone-v1.0.0.zip", "release-manifest.json", "SHA256SUMS.txt")
LIVE_PROCESSES: list[subprocess.Popen] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha(path: Path) -> str:
    with path.open("rb") as stream:
        h = hashlib.sha256()
        for block in iter(lambda: stream.read(1048576), b""):
            h.update(block)
        return h.hexdigest()


def no_reparse(path: Path) -> None:
    cursor = path
    while True:
        if cursor.exists() or cursor.is_symlink():
            info = cursor.lstat()
            require(not stat.S_ISLNK(info.st_mode) and
                    not getattr(info, "st_file_attributes", 0) & 0x400,
                    "Reparse path or ancestor refused.")
        if cursor.parent == cursor:
            break
        cursor = cursor.parent


def absolute(value: str) -> Path:
    require(os.path.isabs(value) and not value.startswith(("\\\\?\\", "\\\\.\\")),
            "Absolute ordinary filesystem paths required.")
    parts = value.replace("\\", "/").split("/")
    require(not any(p in (".", "..") or p.endswith((".", " ")) for p in parts),
            "Dot traversal and path aliases refused.")
    path = Path(os.path.abspath(value))
    require(not any(c in str(path)[3:] for c in '*?<>"|:'), "Filesystem metacharacters refused.")
    no_reparse(path)
    return path


def read_json(path: Path) -> dict:
    no_reparse(path)
    require(path.is_file() and path.stat().st_size <= 2097152, "Bounded JSON file required.")
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    require(isinstance(value, dict), "JSON object required.")
    return value


def inventory(root: Path) -> list[dict]:
    no_reparse(root)
    rows = []
    for directory, subdirs, files in os.walk(root, followlinks=False):
        for name in sorted(subdirs + files):
            path = Path(directory) / name
            no_reparse(path)
            if path.is_file():
                rows.append({"relative_path": path.relative_to(root).as_posix(),
                             "bytes": path.stat().st_size, "sha256": file_sha(path)})
    return sorted(rows, key=lambda r: r["relative_path"])


class Runner:
    def __init__(self, args: argparse.Namespace, root: Path, report: dict):
        self.args, self.root, self.report = args, root, report
        self.logs = root / "raw"
        self.logs.mkdir()
        self.index = 0
        self.last_stderr = b""
        self.replacements = sorted([(str(root), "<OWNED_ZIP_SMOKE>"),
            (str(args.source), "<EXACT_C_SOURCE>"), (str(args.assets), "<LOCAL_ASSETS>"),
            (str(args.evidence), "<PUBLIC_REPORT>"),
            (str(args.dependencies), "<DEPENDENCY_INPUT>"),
            (str(args.ps51), "<PS51>"), (str(args.ps7), "<PS7>"),
            (str(Path(os.environ.get("USERPROFILE", str(root)))), "<USERPROFILE>")],
            key=lambda pair: len(pair[0]), reverse=True)

    def safe(self, value):
        if isinstance(value, dict):
            return {key: self.safe(item) for key, item in value.items()}
        if isinstance(value, list):
            return [self.safe(item) for item in value]
        if isinstance(value, str):
            for original, replacement in self.replacements:
                value = value.replace(original, replacement)
            return value
        return value

    def run(self, command: list[str] | str, *, label: str, env=None,
            expected=(0,), stdin=b"", timeout=90, executable=None) -> bytes:
        self.index += 1
        start = time.monotonic()
        row = {"sequence": self.index, "label": label,
               "command_arguments": self.safe(command), "creation_flags": 0,
               "timeout_seconds": timeout, "expected_exit_codes": list(expected),
               "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
               "exit_code": None, "timed_out": False, "natural_exit_observed": False,
               "pipes_drained_and_closed": False, "process_handle_closed": False}
        self.report["processes"].append(row)
        child = subprocess.Popen(command, executable=executable, cwd=self.root,
            env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, creationflags=0)
        row["owned_pid"] = child.pid
        try:
            out, err = child.communicate(stdin, timeout=timeout)
        except subprocess.TimeoutExpired:
            row["timed_out"] = True
            row["elapsed_seconds"] = round(time.monotonic() - start, 3)
            LIVE_PROCESSES.append(child)
            raise RuntimeError("Owned process timed out; no process kill or cleanup attempted: " + label)
        row["exit_code"] = child.returncode
        self.last_stderr = err
        row["natural_exit_observed"] = child.poll() is not None
        row["pipes_drained_and_closed"] = all(stream is None or stream.closed
            for stream in (child.stdin, child.stdout, child.stderr))
        if os.name == "nt":
            child._handle.Close()  # Windows Popen owns this handle; exit has been observed.
            row["process_handle_closed"] = True
        row["elapsed_seconds"] = round(time.monotonic() - start, 3)
        prefix = f"{self.index:03d}-{label}"
        for suffix, data in (("stdout", out), ("stderr", err)):
            path = self.logs / (prefix + "." + suffix + ".bin")
            with path.open("xb") as stream:
                stream.write(data)
            row[suffix + "_sha256"] = sha(data)
            row[suffix + "_bytes"] = len(data)
            row[suffix + "_private_log"] = path.relative_to(self.root).as_posix()
        require(child.returncode in expected, "Unexpected owned process exit: " + label)
        require(row["natural_exit_observed"] and row["pipes_drained_and_closed"] and
                row["process_handle_closed"], "Owned subprocess release unproved: " + label)
        return out

    def git(self, *arguments: str, expected=(0,)) -> bytes:
        return self.run(["git", "--no-optional-locks", "-C", str(self.args.source),
                         *arguments], label="git-read", expected=expected, timeout=45)


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def blue_png() -> bytes:
    width, height = 24, 16
    pixels = (b"\x00" + b"\x00\x00\xff" * width) * height
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


def probe(runner: Runner, ffprobe: Path, path: Path) -> dict:
    return json.loads(runner.run([str(ffprobe), "-v", "error", "-show_streams",
        "-show_format", "-of", "json", str(path)], label="independent-probe").decode("utf-8"))


def tags(value: dict) -> dict:
    return {key.casefold(): str(item) for key, item in value.get("tags", {}).items()}


def duration(value: dict) -> float:
    audio = [stream for stream in value["streams"] if stream["codec_type"] == "audio"]
    require(len(audio) == 1, "One independently probed audio stream required.")
    return float(audio[0].get("duration", value["format"].get("duration", 0)))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("assets", "source", "source-commit", "workspace", "evidence", "dependencies", "ps51", "ps7"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--test-evidence")
    args = parser.parse_args()
    require(os.name == "nt", "Actual Windows execution required.")
    require(re.fullmatch(r"[0-9a-f]{40}", args.source_commit) is not None, "Full lowercase C required.")
    for name in ("assets", "source", "workspace", "evidence", "dependencies", "ps51", "ps7"):
        setattr(args, name, absolute(getattr(args, name)))
    if args.test_evidence:
        args.test_evidence = absolute(args.test_evidence)
    require(args.source.is_dir() and args.assets.is_dir(), "Existing source and assets required.")
    require(not args.workspace.exists() and args.workspace.parent.is_dir(), "Fresh external run workspace required.")
    require(not args.evidence.exists() and args.evidence.parent.is_dir(), "Fresh evidence file required.")
    require(args.evidence.name.startswith("T23-") and args.evidence.suffix == ".json", "T23 JSON evidence name required.")
    require(not args.workspace.is_relative_to(args.source) and not args.workspace.is_relative_to(args.assets),
            "Smoke workspace must be external to source/assets.")
    require(not args.evidence.is_relative_to(args.source) and not args.evidence.is_relative_to(args.assets),
            "Evidence output cannot dirty frozen source/assets.")
    args.workspace.mkdir()
    token = uuid.uuid4().hex
    marker = args.workspace / ".t23-zip-owner"
    with marker.open("x", encoding="ascii") as stream:
        stream.write(token)
    report = {"schema_version": 1, "task": "T23", "cases": ["A55", "A56"],
        "mode": "exact_zip_direct_windows_smoke", "status": "fail", "tested_commit": args.source_commit,
        "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "processes": [], "checks": [],
        "tool_sha256": file_sha(Path(__file__)), "owned_workspace_name": args.workspace.name,
        "marker_sha256": file_sha(marker), "workspace_retained": True,
        "ordinary_music_conversion_or_enumeration": False, "physical_manual_or_phone_test": False,
        "controller_killed_processes": False, "global_environment_or_console_changes": False,
        "python": sys.version.split()[0], "windows_version": str(sys.getwindowsversion()),
        "console_output_code_page": ctypes.windll.kernel32.GetConsoleOutputCP(),
        "limitations": ["Local extracted ZIP technical smoke; phone results are reused separately through exact payload equivalence.",
            "Direct subprocess natural exit and handle/pipe release are observed. Application internal child handles are not instrumented by this smoke.",
            "BAT failures launch the real adjacent app, before Music resolution; no new Explorer drag/drop or interactive UI observation.",
            "All owned synthetic media and raw output are retained externally; no cleanup or process kill is attempted."]}
    runner = Runner(args, args.workspace, report)
    assets_before = []
    tracked_before = []
    fixtures_before = None
    extractions = []
    tools_before = {}
    inputs_before = {"dependencies": file_sha(args.dependencies)}
    if args.test_evidence:
        inputs_before["test_evidence"] = file_sha(args.test_evidence)
    try:
        assets_before = inventory(args.assets)
        require([row["relative_path"] for row in assets_before] == sorted(ASSETS), "Exactly three asset files required.")
        require(runner.git("rev-parse", "HEAD").decode().strip() == args.source_commit, "Source HEAD differs from C.")
        require(not runner.git("symbolic-ref", "--quiet", "HEAD", expected=(1,)), "Detached C source required.")
        require(not runner.git("status", "--porcelain=v1", "--untracked-files=all", "--ignored=matching"), "Source must be pristine.")
        tracked = runner.git("ls-files", "-z").decode("utf-8").split("\x00")
        for name in tracked:
            if name:
                no_reparse(args.source / name)
                tracked_before.append({"relative_path": name, "sha256": file_sha(args.source / name)})
        manifest = read_json(args.assets / ASSETS[1])
        require(manifest.get("schema_version") == 1 and manifest.get("repository") == "PikkuJanne/AudioFileForPhone" and
                manifest.get("app_version") == "1.0.0" and manifest.get("tag") == "v1.0.0" and
                manifest.get("release_commit") == args.source_commit, "Manifest identity/version/C mismatch.")
        require(manifest["zip"] == {"name": ASSETS[0], "bytes": (args.assets / ASSETS[0]).stat().st_size,
            "sha256": file_sha(args.assets / ASSETS[0])}, "Manifest ZIP size/hash mismatch.")
        sums = (args.assets / ASSETS[2]).read_text(encoding="utf-8-sig").splitlines()
        require(sums == [file_sha(args.assets / ASSETS[0]) + "  " + ASSETS[0],
            file_sha(args.assets / ASSETS[1]) + "  " + ASSETS[1]], "Exact non-self-referencing checksum lines required.")
        require(list(manifest["files"]) == MEMBERS and set(manifest["file_bytes"]) == set(MEMBERS), "Exact manifest member policy required.")
        require(manifest["build"]["source_mode"] == "clean_detached_exact_git_blobs" and
                manifest["build"]["archive_order"] == "Ordinal" and
                manifest["build"]["zip_timestamp_utc"] == "1980-01-01T00:00:00Z", "Manifest build policy mismatch.")
        payload = {}
        source_members = []
        with zipfile.ZipFile(args.assets / ASSETS[0]) as archive:
            require([entry.filename for entry in archive.infolist()] == MEMBERS, "ZIP inventory/order mismatch.")
            for entry in archive.infolist():
                require(entry.filename in MEMBERS and not entry.is_dir() and not entry.flag_bits & 1 and
                    entry.external_attr == 0 and entry.file_size <= 10485760 and
                    entry.date_time == (1980, 1, 1, 0, 0, 0), "Unsafe ZIP member or build attributes.")
                data = archive.read(entry)
                blob = runner.git("cat-file", "blob", args.source_commit + ":" + entry.filename)
                oid = hashlib.sha1(b"blob " + str(len(blob)).encode("ascii") + b"\0" + blob).hexdigest()
                tree = runner.git("ls-tree", args.source_commit, "--", entry.filename).decode().strip()
                require(re.fullmatch(r"100(?:644|755) blob " + oid + r"\t" + re.escape(entry.filename), tree) is not None,
                        "Member is not an independently verified regular C blob.")
                require(data == blob and sha(data) == manifest["files"][entry.filename] and
                    len(data) == manifest["file_bytes"][entry.filename], "Member bytes/hash/length differ from C.")
                payload[entry.filename] = data
                source_members.append({"relative_path": entry.filename, "bytes": len(blob),
                                       "sha256": sha(blob), "git_blob_oid": oid})
        for member, field in (("tools/Build-Package.ps1", "builder_sha256"), ("tools/package-files.json", "allowlist_sha256")):
            blob = runner.git("cat-file", "blob", args.source_commit + ":" + member)
            require(sha(blob) == manifest["build"][field], "Build/allowlist provenance differs from C.")
            if field == "allowlist_sha256":
                allow = json.loads(blob.decode("utf-8-sig"))
                require(allow["schema_version"] == 1 and sorted(allow["files"]) == MEMBERS, "C allowlist mismatch.")
        report["source_members"] = source_members
        attestations = manifest.get("test_evidence")
        require(isinstance(attestations, list) and bool(attestations), "Nonempty manifest test attestations required.")
        require(len({row["reference"] for row in attestations}) == len(attestations) and all(
            row["status"] == "pass" and row["tested_commit"] == args.source_commit and
            re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) and
            re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", row["reference"]) and
            not any(part in ("", ".", "..") for part in row["reference"].split("/"))
            for row in attestations), "Manifest passing exact-C attestation contract mismatch.")
        require(re.fullmatch(r"[0-9a-f]{64}", manifest["build"]["inputs"]["test_evidence_sha256"]), "Test input digest required.")
        if args.test_evidence:
            test_input = read_json(args.test_evidence)
            require(test_input["schema_version"] == 1 and test_input["tests"] == attestations and
                file_sha(args.test_evidence) == manifest["build"]["inputs"]["test_evidence_sha256"], "Actual test-attestation input differs from manifest.")
        report["manifest_test_evidence"] = attestations
        report["test_attestation_scope"] = "Form and C binding; truth/original report source relationships are independently audited by the T23 binder."
        dep = read_json(args.dependencies)
        require(dep["schema_version"] == 1 and manifest["dependencies"]["bundled"] is False and
            manifest["build"]["inputs"]["dependency_provenance_sha256"] == file_sha(args.dependencies), "Dependency input digest/schema mismatch.")
        tools = {}
        for name in ("ffmpeg", "ffprobe"):
            item, public = dep[name], manifest["dependencies"][name]
            tools[name] = absolute(item["path"])
            require(tools[name].name.casefold() == name + ".exe" and
                file_sha(tools[name]) == item["sha256"] == public["sha256"], "Dependency executable identity mismatch.")
            tools_before[name] = file_sha(tools[name])
            require(public["executable_name"] == name + ".exe" and all(public[key] == item[key]
                for key in ("version", "source_url", "license_notice")), "Public dependency provenance mismatch.")
            version_args = (["-nostdin"] if name == "ffmpeg" else []) + ["-version"]
            version = runner.run([str(tools[name]), *version_args], label=name + "-version").decode("utf-8").splitlines()[0]
            require(version == item["version"], "Actual dependency version differs from provenance.")
        encoders = runner.run([str(tools["ffmpeg"]), "-nostdin", "-hide_banner", "-encoders"], label="encoder-capabilities").decode("utf-8")
        require(re.search(r"(?m)^\s*A\S*\s+libmp3lame\s", encoders) is not None, "libmp3lame unavailable.")
        report["dependencies"] = manifest["dependencies"]
        fixtures = args.workspace / "fixtures"
        input_root = fixtures / "Input"
        (input_root / "Nested").mkdir(parents=True)
        expected_tags = {}
        kinds = (("mp3", "libmp3lame", "2024-01-01 Source.mp3"),
                 ("m4a", "aac", "Nested/2024-01-02 Source.m4a"),
                 ("vorbis", "libvorbis", "Nested/2024-01-03 Vorbis.ogg"),
                 ("opus", "libopus", "2024-01-04 Opus.ogg"))
        for index, (kind, codec, relative) in enumerate(kinds):
            path = input_root / relative
            metadata = {"title": "T23 source " + kind + " é", "artist": "T23 Source Artist",
                        "album": "T23 Source Album", "comment": "T23 synthetic only", "track": "3/9", "disc": "2/4"}
            command = [str(tools["ffmpeg"]), "-nostdin", "-v", "error", "-f", "lavfi", "-i",
                "sine=frequency=" + str(440 + index * 110) + ":sample_rate=44100", "-t", "0.5",
                "-c:a", codec, "-b:a", "64k"]
            for key, value in metadata.items():
                command += ["-metadata", key + "=" + value]
            runner.run(command + [str(path)], label="fixture-" + kind)
            observed = probe(runner, tools["ffprobe"], path)
            require(0 < duration(observed) <= 1, "Actual short synthetic input duration required.")
            source_tags = tags(observed["streams"][0] if path.suffix == ".ogg" else observed["format"])
            require(all(source_tags.get(key) == value for key, value in metadata.items()), "Fixture metadata not actually established.")
            expected_tags[relative] = metadata
            report.setdefault("synthetic_fixtures", []).append({"relative_path": relative, "kind": kind,
                "codec": observed["streams"][0]["codec_name"], "duration_seconds": duration(observed), "tags": metadata})
        cover = fixtures / "blue.png"
        with cover.open("xb") as stream:
            stream.write(blue_png())
        cover_jpg = fixtures / "blue.jpg"
        runner.run([str(tools["ffmpeg"]), "-nostdin", "-v", "error", "-i", str(cover),
                    "-frames:v", "1", str(cover_jpg)], label="fixture-jpg")
        fixtures_before = inventory(fixtures)
        system = Path(os.environ["SystemRoot"]) / "System32"
        cmd = system / "cmd.exe"
        ps51_dir = system / "WindowsPowerShell" / "v1.0"
        require(cmd.is_file() and args.ps51.is_file() and args.ps7.is_file(), "Both real supported shells and cmd required.")
        for shell_label, shell in (("ps51", args.ps51), ("ps7", args.ps7)):
            app_root = args.workspace / shell_label / "package"
            app_root.mkdir(parents=True)
            for name, data in payload.items():
                with (app_root / name).open("xb") as stream:
                    stream.write(data)
            package_before = inventory(app_root)
            extractions.append((app_root, package_before))
            child_env = {key: value for key, value in os.environ.items() if key.upper() != "PSMODULEPATH"}
            child_env["PATH"] = os.pathsep.join(dict.fromkeys((str(tools["ffmpeg"].parent),
                str(tools["ffprobe"].parent), str(system), str(ps51_dir), str(shell.parent))))
            # Inert inspection, outside the package. No runtime file is changed.
            inspect = args.workspace / (shell_label + "-inspect.ps1")
            inspect.write_text("param([string]$Package)\n$ErrorActionPreference='Stop'\n"
                "$rows=@();foreach($n in @('AudioFileForPhone.Helpers.ps1','AudioFileForPhone.ps1')){"
                "$s=Get-AuthenticodeSignature -LiteralPath (Join-Path $Package $n);"
                "$rows+=@{name=$n;status=[string]$s.Status;thumbprint=$(if($null -eq $s.SignerCertificate){$null}else{$s.SignerCertificate.Thumbprint})}}\n"
                ". (Join-Path $Package 'AudioFileForPhone.Helpers.ps1')\n"
                "@{version=(Get-AudioAppVersion);shell=$PSVersionTable.PSVersion.ToString();edition=$PSVersionTable.PSEdition;signatures=$rows}|ConvertTo-Json -Depth 5\n",
                encoding="utf-8-sig")
            inspected = json.loads(runner.run([str(shell), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned",
                "-File", str(inspect), "-Package", str(app_root)], label=shell_label + "-signature-version", env=child_env).decode("utf-8-sig"))
            require(inspected["version"] == "1.0.0" and inspected["edition"] == ("Desktop" if shell_label == "ps51" else "Core"), "Actual extracted version/shell mismatch.")
            for signature in inspected["signatures"]:
                public = manifest["signatures"][signature["name"]]
                require(signature["status"] == public["status"] and signature["thumbprint"] == public["signer_thumbprint"], "Actual extracted signing observation mismatch.")
            statuses = [row["status"] for row in inspected["signatures"]]
            actual_signing = ("unsigned" if all(s == "NotSigned" for s in statuses) else
                "signed_valid_on_build_host" if all(s == "Valid" for s in statuses) else "mixed_or_invalid")
            require(actual_signing == manifest["signing_status"], "Aggregate signing state mismatch.")
            report.setdefault("shells", []).append(inspected)
            for mode, image in (("default", None), ("png-overrides", cover), ("jpg-overrides", cover_jpg)):
                output_parent = args.workspace / shell_label / mode
                output_parent.mkdir()
                command = [str(shell), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned",
                    "-File", str(app_root / "AudioFileForPhone.ps1"), "-InputFolder", str(input_root), "-OutputParent", str(output_parent)]
                if image:
                    command += ["-CoverPath", str(image), "-Artist", "T23 Override Artist", "-Album", "T23 Override Album"]
                runner.run(command, label=shell_label + "-" + mode, env=child_env, timeout=120)
                roots = list(output_parent.iterdir())
                require(len(roots) == 1 and roots[0].is_dir() and re.fullmatch(r"AudioForPhone_64kbps_\d{8}_\d{6}(?:_\d+)?", roots[0].name), "Exactly one default64 run required.")
                run_root = roots[0]
                run_inventory = inventory(run_root)
                require(not any(row["relative_path"].endswith(".partial") for row in run_inventory), "Partial file remains.")
                local = read_json(run_root / "AudioFileForPhone_manifest.json")
                identity = read_json(run_root / ".AudioFileForPhone-output.json")
                require(identity["kind"] == "AudioFileForPhone.Output" and identity["output_root"] == str(run_root) and
                    identity["cleanup_scope"] == str(run_root) and re.fullmatch(r"[0-9a-f]{32}", identity["ownership_token"]), "Runtime marker ownership mismatch.")
                require(local["run"]["status"] == "Completed" and local["run"]["exit_code"] == 0 and local["checkpoint"] == "Final" and
                    local["totals"]["supported"] == local["totals"]["processed"] == local["totals"]["converted"] == 4 and
                    local["totals"]["failed"] == local["totals"]["cancelled"] == local["totals"]["not_processed"] == 0 and len(local["records"]) == 4,
                    "Final manifest/run totals mismatch.")
                require(local["build"]["entry_sha256"] == manifest["files"]["AudioFileForPhone.ps1"] and
                    local["build"]["helper_sha256"] == manifest["files"]["AudioFileForPhone.Helpers.ps1"] and
                    local["policies"]["bitrate_kbps"] == 64 and local["policies"]["recursive_relative_layout"] is True and
                    local["policies"]["full_output_decode_required"] is True, "Actual exact ZIP runtime/default policy mismatch.")
                case = {"shell": shell_label, "name": mode, "status": "pass", "outputs": [],
                    "runtime_manifest_sha256": file_sha(run_root / "AudioFileForPhone_manifest.json"),
                    "marker_sha256": file_sha(run_root / ".AudioFileForPhone-output.json")}
                output_paths = []
                for record in local["records"]:
                    relative = record["source_relative_path"].replace("\\", "/")
                    require(relative in expected_tags and record["status"] == "Converted" and record["measurement_error"] == "", "Record source/status mismatch.")
                    out_relative = record["output_relative_path"].replace("\\", "/")
                    parts = out_relative.split("/")
                    src_parts = relative.split("/")
                    require(parts[:-1] == [input_root.name] + src_parts[:-1] and
                        parts[-1].startswith(src_parts[-1][:10] + " ") and parts[-1].endswith(".mp3"), "Date-first recursive output layout mismatch.")
                    output = run_root.joinpath(*parts)
                    require(output.is_file() and output.stat().st_size == record["output_bytes"], "Output bytes mismatch.")
                    output_paths.append(out_relative)
                    observed = probe(runner, tools["ffprobe"], output)
                    audio = [stream for stream in observed["streams"] if stream["codec_type"] == "audio"]
                    video = [stream for stream in observed["streams"] if stream["codec_type"] == "video"]
                    require(len(audio) == 1 and audio[0]["codec_name"] == "mp3" and int(audio[0]["bit_rate"]) == 64000,
                            "Independent 64kbps MP3 probe mismatch.")
                    seconds = duration(observed)
                    require(abs(seconds - float(record["input_duration_seconds"])) <= .35 and
                        abs(seconds - float(record["output_duration_seconds"])) < .000001 and
                        float(record["decoded_duration_seconds"]) > 0, "Independent duration mismatch.")
                    expected = dict(expected_tags[relative])
                    if image:
                        expected.update(artist="T23 Override Artist", album="T23 Override Album")
                    require(all(tags(observed["format"]).get(key) == value for key, value in expected.items()), "Metadata preservation/override mismatch.")
                    runner.run([str(tools["ffmpeg"]), "-nostdin", "-v", "error", "-xerror", "-i", str(output),
                        "-map", "0:a:0", "-f", "null", "NUL"], label="full-audio-decode")
                    require(len(video) == (1 if image else 0), "Artwork stream policy mismatch.")
                    if image:
                        require(video[0]["disposition"]["attached_pic"] == 1 and video[0]["width"] == 24 and video[0]["height"] == 16,
                                "Artwork dimensions/disposition mismatch.")
                        rgb = runner.run([str(tools["ffmpeg"]), "-nostdin", "-v", "error", "-xerror", "-i", str(output),
                            "-map", "0:v:0", "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"], label="full-artwork-decode")
                        require(len(rgb) == 24 * 16 * 3 and sum(rgb[2::3]) / (24 * 16) > 230 and
                            sum(rgb[0::3]) / (24 * 16) < 25 and sum(rgb[1::3]) / (24 * 16) < 25, "Decoded cover is not the synthetic blue image.")
                    case["outputs"].append({"source_relative_path": relative, "output_relative_path": out_relative,
                        "bytes": output.stat().st_size, "sha256": file_sha(output), "audio_bitrate": 64000,
                        "duration_seconds": seconds, "fully_decoded": True, "cover_decoded": bool(image)})
                actual_outputs = [row["relative_path"] for row in run_inventory if row["relative_path"].endswith(".mp3")]
                require(sorted(actual_outputs) == sorted(output_paths), "Unexpected or missing published MP3.")
                report["checks"].append(case)
            # Real BAT/adjacent application failures occur before Music resolution.
            bat_env = dict(child_env)
            bat_env["PATH"] = os.pathsep.join([str(args.ps7.parent), str(system), str(ps51_dir)] if shell_label == "ps7" else [str(system), str(ps51_dir)])
            bat_env["PATHEXT"] = ".COM;.EXE;.BAT;.CMD"
            bat_env["AFP_T23_BAT"] = str(app_root / "AudioFileForPhone.bat")
            bat_env["AFP_T23_INPUT"] = str(args.workspace / "never-created-input")
            stdout = runner.run('"' + str(cmd) + '" /d /v:off /s /c ""%AFP_T23_BAT%" "%AFP_T23_INPUT%""',
                executable=str(cmd), label=shell_label + "-actual-bat-negative", env=bat_env, stdin=b"\r\n", expected=(1,), timeout=45)
            combined = stdout + runner.last_stderr
            require(b"Failed. Review" in stdout and b"Completed. Check" not in stdout and b"Preflight failed" in combined,
                    "Actual BAT missing-input result mismatch.")
            report["checks"].append({"shell": shell_label, "name": "actual-bat-missing-input", "status": "pass", "exit_code": 1,
                                    "fails_before_music_resolution": True})
            missing_parent = args.workspace / shell_label / "missing-dependency-output"
            missing_parent.mkdir()
            missing_env = dict(child_env)
            missing_env["PATH"] = os.pathsep.join((str(system), str(ps51_dir)))
            stdout = runner.run([str(shell), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned",
                "-File", str(app_root / "AudioFileForPhone.ps1"), "-InputFolder", str(input_root), "-OutputParent", str(missing_parent)],
                label=shell_label + "-missing-dependency", env=missing_env, expected=(1,), timeout=45)
            combined = stdout + runner.last_stderr
            require(not list(missing_parent.iterdir()) and b"ffmpeg.exe" in combined and b"Preflight failed" in combined,
                    "Missing dependency must fail before run/output publication.")
            report["checks"].append({"shell": shell_label, "name": "missing-ffmpeg", "status": "pass", "exit_code": 1,
                                    "output_parent_empty": True})
        report["status"] = "pass"
    except Exception as error:
        report["error"] = runner.safe(str(error))
    finally:
        try:
            report["assets_before"] = assets_before
            report["assets_after"] = inventory(args.assets)
            report["assets_unchanged"] = report["assets_before"] == report["assets_after"]
            report["extracted_packages"] = [{"shell": path.parent.name, "before": before,
                "after": inventory(path), "unchanged": before == inventory(path)} for path, before in extractions]
            if tracked_before:
                after = [{"relative_path": row["relative_path"], "sha256": file_sha(args.source / row["relative_path"])} for row in tracked_before]
                report["tracked_source_file_count"] = len(tracked_before)
                report["tracked_source_inventory_sha256_before"] = sha(json.dumps(tracked_before, sort_keys=True, separators=(",", ":")).encode())
                report["tracked_source_inventory_sha256_after"] = sha(json.dumps(after, sort_keys=True, separators=(",", ":")).encode())
                report["source_unchanged"] = after == tracked_before
                report["source_still_detached_at_C"] = runner.git("rev-parse", "HEAD").decode().strip() == args.source_commit and not runner.git("symbolic-ref", "--quiet", "HEAD", expected=(1,))
                report["source_still_pristine"] = not runner.git("status", "--porcelain=v1", "--untracked-files=all", "--ignored=matching")
            if fixtures_before is not None:
                report["fixtures_before"] = fixtures_before
                report["fixtures_after"] = inventory(args.workspace / "fixtures")
                report["fixtures_unchanged"] = report["fixtures_before"] == report["fixtures_after"]
            report["dependencies_unchanged"] = all(file_sha(tools[name]) == digest for name, digest in tools_before.items())
            report["provenance_inputs_unchanged"] = file_sha(args.dependencies) == inputs_before["dependencies"] and (
                not args.test_evidence or file_sha(args.test_evidence) == inputs_before["test_evidence"])
            report["ownership_marker_unchanged"] = marker.read_text(encoding="ascii") == token
            required = ("assets_unchanged", "source_unchanged", "source_still_detached_at_C", "source_still_pristine",
                        "fixtures_unchanged", "dependencies_unchanged", "provenance_inputs_unchanged", "ownership_marker_unchanged")
            if not all(report.get(name) is True for name in required) or not all(row["unchanged"] for row in report["extracted_packages"]):
                report["status"] = "fail"
        except Exception as error:
            report["status"] = "fail"
            report["preservation_error"] = runner.safe(str(error))
        report["completed_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        report["direct_process_release_proved"] = all(row["natural_exit_observed"] and row["pipes_drained_and_closed"] and
            row["process_handle_closed"] and not row["timed_out"] for row in report["processes"])
        if not report["direct_process_release_proved"]:
            report["status"] = "fail"
        with args.evidence.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(runner.safe(report), stream, ensure_ascii=False, indent=2)
            stream.write("\n")
    print("T23 ZIP smoke: " + report["status"] + "; checks=" + str(len(report["checks"])) + "; processes=" + str(len(report["processes"])))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
