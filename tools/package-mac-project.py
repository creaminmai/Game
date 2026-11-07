#!/usr/bin/env python3
"""Package committed Godot sources for importing on Mac, without engine caches."""
import argparse
import hashlib
import io
import json
import stat
import subprocess
import tarfile
import zipfile
from pathlib import Path, PurePosixPath


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=repo / "artifacts/mac")
    args = parser.parse_args()
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repo, text=True
    ).strip()
    # Archive committed files only: no .godot cache, saves, credentials or binaries.
    archive = subprocess.check_output(
        ["git", "archive", "--format=tar", commit, "godot"], cwd=repo
    )
    root = "햇살병원-Mac"
    payload = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for member in source.getmembers():
            if not member.isfile():
                continue
            relative = PurePosixPath(member.name).relative_to("godot")
            # The Web preset references cloud-only export templates. F5 needs none.
            if relative.as_posix() == "export_presets.cfg":
                continue
            payload[f"{root}/햇살병원/{relative}"] = source.extractfile(member).read()
    if f"{root}/햇살병원/project.godot" not in payload:
        raise SystemExit("Missing project.godot")
    manifest = {
        "source_commit": commit,
        "godot_version": "4.6.3",
        "renderer": "GL Compatibility",
        "omitted": ["godot/export_presets.cfg (cloud Web export only)"],
        "sha256": {
            name.removeprefix(f"{root}/햇살병원/"): hashlib.sha256(data).hexdigest()
            for name, data in sorted(payload.items())
        },
    }
    payload[f"{root}/햇살병원/패키지-정보.json"] = (
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    ).encode()
    payload[f"{root}/KMH에 설치.command"] = (repo / "tools/mac-install.command").read_bytes()
    payload[f"{root}/햇살병원/첫날 이야기 체험.command"] = (repo / "tools/mac-first-day.command").read_bytes()
    guide = (repo / "docs/mac-play.md").read_bytes()
    payload[f"{root}/먼저 읽어주세요.txt"] = guide
    payload[f"{root}/햇살병원/Mac 실행 안내.txt"] = guide

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / f"SunshineHospital-Mac-Godot-{commit[:7]}.zip"
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as result:
        for name, data in sorted(payload.items()):
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            mode = 0o755 if name.endswith(".command") else 0o644
            entry.external_attr = (stat.S_IFREG | mode) << 16
            result.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(output) as result:
        if result.testzip() is not None:
            raise SystemExit("ZIP integrity check failed")
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".zip.sha256").write_text(f"{digest}  {output.name}\n")
    print(json.dumps({"zip": str(output), "bytes": output.stat().st_size,
                      "source_commit": commit, "project_files": len(manifest["sha256"]),
                      "sha256": digest}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
