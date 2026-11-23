#!/usr/bin/env python3
"""Normalize DB Score drum-course containers without changing rhythm content.

The legacy MusicXML conversion pipeline produced three unstable defaults:
* pitched percussion notes were stored outside the Drum Kit pitch map;
* text styles referenced the Windows-only SimHei family;
* audiosettings.json contained an empty tracks array.

This utility remaps only the known legacy drum pitches and rewrites those two
metadata entries. Every other ZIP entry is copied byte-for-byte, and each
replacement is validated before it is committed.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile
import zipfile


FONT_FACE_PATTERN = re.compile(
    rb"(<([A-Za-z0-9]+FontFace)>)\s*SimHei\s*(</\2>)",
    re.IGNORECASE,
)
INLINE_FONT_FACE_PATTERN = re.compile(
    rb"""(\<font\s+[^>]*\bface=["'])SimHei(["'])""",
    re.IGNORECASE,
)
PART_ID_PATTERN = re.compile(rb"""<Part\s+id=["'](\d+)["']""")
NOTE_BLOCK_PATTERN = re.compile(
    rb"(<Note\b[^>]*>)(.*?)(</Note>)",
    re.DOTALL,
)
PITCH_PATTERN = re.compile(rb"<pitch>(\d+)</pitch>")
TPC_PATTERN = re.compile(rb"<tpc>(-?\d+)</tpc>")
DRUM_PITCH_PATTERN = re.compile(rb"""<Drum\s+pitch=["'](\d+)["']""")

# Sibelius/MusicXML exports can encode drum-staff positions as pitched notes.
# These pairs consistently represent the same drum kit in the legacy pipeline.
LEGACY_DRUM_NOTE_MAP = {
    b"62": (b"16", b"44", b"22"),
    b"64": (b"18", b"35", b"19"),
    b"65": (b"13", b"36", b"14"),
    b"67": (b"15", b"41", b"13"),
    b"69": (b"17", b"43", b"15"),
    b"71": (b"19", b"45", b"17"),
    b"72": (b"14", b"38", b"16"),
    b"74": (b"16", b"47", b"19"),
    b"76": (b"18", b"48", b"14"),
    b"77": (b"13", b"53", b"13"),
    b"79": (b"15", b"42", b"20"),
    b"81": (b"17", b"49", b"21"),
    b"83": (b"19", b"57", b"17"),
}

FLUID_AUDIO_RESOURCE = {
    "attributes": {
        "playbackSetupData": "last.last.last",
        "soundFontName": "FluidR3_GM",
    },
    "id": "FluidR3_GM",
    "type": "fluid_soundfont",
    "vendor": "Fluid",
}

DEFAULT_AUDIO_SETTINGS = {
    "activeSoundProfile": "DBScore Basic",
    "aux": [
        {
            "out": {
                "balance": 0,
                "fxChain": {
                    "0": {
                        "active": True,
                        "chainOrder": 0,
                        "resourceMeta": {
                            "attributes": {
                                "hasNativeEditorSupport": "true",
                            },
                            "id": "Muse Reverb",
                            "type": "muse_plugin",
                            "vendor": "Muse",
                        },
                        "unitConfiguration": {},
                    },
                },
                "volumeDb": 0,
            },
        },
        {
            "out": {
                "balance": 0,
                "fxChain": {},
                "volumeDb": 0,
            },
        },
    ],
    "master": {
        "balance": 0,
        "fxChain": {},
        "volumeDb": 0,
    },
    "tracks": [
        {
            "in": {
                "resourceMeta": FLUID_AUDIO_RESOURCE,
                "unitConfiguration": {},
            },
            "instrumentId": "drumset",
            "out": {
                "auxSends": [
                    {
                        "active": True,
                        "signalAmount": 0.30000001192092896,
                    },
                    {
                        "active": True,
                        "signalAmount": 0.30000001192092896,
                    },
                ],
                "balance": 0,
                "fxChain": {},
                "volumeDb": 0,
            },
            "partId": "1",
        },
        {
            "in": {
                "resourceMeta": FLUID_AUDIO_RESOURCE,
                "unitConfiguration": {},
            },
            "instrumentId": "metronome",
            "out": {
                "balance": 0,
                "fxChain": {},
                "volumeDb": 0,
            },
            "partId": "999",
        },
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize legacy DB course font and audio metadata.",
    )
    parser.add_argument(
        "paths",
        nargs="+",
        type=Path,
        help="Course .db files or directories to scan recursively.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report required changes without writing files.",
    )
    parser.add_argument(
        "--backup-dir",
        type=Path,
        help="Copy each modified original into this directory before replacing it.",
    )
    parser.add_argument(
        "--backup-base",
        type=Path,
        help="Directory used to preserve relative paths inside --backup-dir.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Only print the final summary and errors.",
    )
    return parser.parse_args()


def collect_db_files(paths: list[Path]) -> list[Path]:
    result: set[Path] = set()
    for path in paths:
        path = path.expanduser().resolve()
        if path.is_dir():
            result.update(item.resolve() for item in path.rglob("*.db") if item.is_file())
        elif path.is_file() and path.suffix.lower() == ".db":
            result.add(path)
        else:
            raise FileNotFoundError(f"Not a .db file or directory: {path}")
    return sorted(result, key=lambda item: str(item).lower())


def replace_font_metadata(name: str, data: bytes) -> tuple[bytes, int]:
    if name.endswith(".mss"):
        updated, style_count = FONT_FACE_PATTERN.subn(rb"\1Edwin\3", data)
        return updated, style_count
    if name.endswith(".mscx"):
        updated, inline_style_count = FONT_FACE_PATTERN.subn(rb"\1Edwin\3", data)
        updated, inline_count = INLINE_FONT_FACE_PATTERN.subn(rb"\1Edwin\2", updated)
        return updated, inline_style_count + inline_count
    return data, 0


def normalize_audio_settings(data: bytes, part_id: str) -> tuple[bytes, bool]:
    try:
        settings = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid audiosettings.json: {error}") from error

    tracks = settings.get("tracks")
    if isinstance(tracks, list) and tracks:
        return data, False

    normalized = copy.deepcopy(DEFAULT_AUDIO_SETTINGS)
    normalized["tracks"][0]["partId"] = part_id
    normalized["tracks"][1]["partId"] = "999"

    # Preserve valid project-level audio values when a partially populated file
    # is encountered. An empty tracks array is the only field being repaired.
    if isinstance(settings.get("audioTrack"), dict):
        normalized["audioTrack"] = settings["audioTrack"]
    if settings.get("activeSoundProfile"):
        normalized["activeSoundProfile"] = settings["activeSoundProfile"]
    if isinstance(settings.get("aux"), list) and settings["aux"]:
        normalized["aux"] = settings["aux"]
    if isinstance(settings.get("master"), dict) and settings["master"]:
        normalized["master"] = settings["master"]

    payload = (json.dumps(normalized, ensure_ascii=False, indent=4) + "\n").encode("utf-8")
    return payload, True


def normalize_legacy_drum_notes(name: str, data: bytes) -> tuple[bytes, int]:
    if not name.endswith(".mscx"):
        return data, 0

    remapped = 0

    def replace_note(match: re.Match[bytes]) -> bytes:
        nonlocal remapped
        opening, body, closing = match.groups()
        pitch = PITCH_PATTERN.search(body)
        if not pitch:
            return match.group(0)

        replacement = LEGACY_DRUM_NOTE_MAP.get(pitch.group(1))
        if replacement is None:
            return match.group(0)

        tpc = TPC_PATTERN.search(body)
        if not tpc:
            raise ValueError(
                f"legacy drum pitch {pitch.group(1).decode()} has no tpc",
            )
        if tpc.group(1) != replacement[0]:
            raise ValueError(
                "unexpected legacy drum pitch/tpc pair: "
                f"{pitch.group(1).decode()}:{tpc.group(1).decode()}",
            )

        body = PITCH_PATTERN.sub(
            rb"<pitch>" + replacement[1] + rb"</pitch>",
            body,
            count=1,
        )
        body = TPC_PATTERN.sub(
            rb"<tpc>" + replacement[2] + rb"</tpc>",
            body,
            count=1,
        )
        remapped += 1
        return opening + body + closing

    return NOTE_BLOCK_PATTERN.sub(replace_note, data), remapped


def validate_drum_score(name: str, data: bytes) -> str:
    if not name.endswith(".mscx"):
        raise ValueError(f"unexpected score entry: {name}")
    if b"<useDrumset>1</useDrumset>" not in data:
        raise ValueError("score is not a drum-set score")

    drum_pitches = set(DRUM_PITCH_PATTERN.findall(data))
    used_pitches: set[bytes] = set()
    for note_match in NOTE_BLOCK_PATTERN.finditer(data):
        pitch = PITCH_PATTERN.search(note_match.group(2))
        if pitch:
            used_pitches.add(pitch.group(1))
    unmapped = sorted(
        (pitch.decode("ascii") for pitch in used_pitches - drum_pitches),
        key=int,
    )
    if unmapped:
        raise ValueError(
            "score contains unmapped drum pitches: " + ", ".join(unmapped),
        )

    match = PART_ID_PATTERN.search(data)
    if not match:
        raise ValueError("score has no Part id")
    return match.group(1).decode("ascii")


def prepare_archive(path: Path) -> tuple[list[tuple[zipfile.ZipInfo, bytes]], dict[str, int]]:
    changes = {
        "font_replacements": 0,
        "pitch_remapped": 0,
        "audio_fixed": 0,
    }
    entries: list[tuple[zipfile.ZipInfo, bytes]] = []
    score_entries = 0
    part_id: str | None = None
    audio_index: int | None = None

    with zipfile.ZipFile(path, "r") as archive:
        bad_entry = archive.testzip()
        if bad_entry:
            raise ValueError(f"corrupt ZIP entry: {bad_entry}")

        for info in archive.infolist():
            data = archive.read(info)
            if info.filename.endswith(".mscx"):
                data, remapped = normalize_legacy_drum_notes(info.filename, data)
                changes["pitch_remapped"] += remapped
                part_id = validate_drum_score(info.filename, data)
                score_entries += 1
            updated, count = replace_font_metadata(info.filename, data)
            changes["font_replacements"] += count
            entries.append((info, updated))
            if info.filename == "audiosettings.json":
                audio_index = len(entries) - 1

        if score_entries != 1:
            raise ValueError(f"expected one .mscx score, found {score_entries}")
        if audio_index is None:
            raise ValueError("audiosettings.json is missing")

        audio_info, audio_data = entries[audio_index]
        normalized_audio, audio_changed = normalize_audio_settings(audio_data, part_id or "1")
        if audio_changed:
            entries[audio_index] = (audio_info, normalized_audio)
            changes["audio_fixed"] = 1

    return entries, changes


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def backup_path_for(path: Path, backup_dir: Path, backup_base: Path | None) -> Path:
    base = backup_base or Path.home()
    try:
        relative = path.relative_to(base.resolve())
    except ValueError:
        relative = Path(path.name)
    return backup_dir / relative


def write_archive_atomic(
    path: Path,
    entries: list[tuple[zipfile.ZipInfo, bytes]],
    backup_dir: Path | None,
    backup_base: Path | None,
) -> None:
    original_mode = stat.S_IMODE(path.stat().st_mode)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".normalizing",
        dir=path.parent,
    )
    os.close(descriptor)
    temporary_path = Path(temporary_name)

    try:
        with zipfile.ZipFile(temporary_path, "w") as archive:
            for info, data in entries:
                archive.writestr(info, data)

        with zipfile.ZipFile(temporary_path, "r") as archive:
            bad_entry = archive.testzip()
            if bad_entry:
                raise ValueError(f"rewritten ZIP is corrupt at {bad_entry}")
            names = set(archive.namelist())
            if "audiosettings.json" not in names:
                raise ValueError("rewritten ZIP lost audiosettings.json")
            if not any(name.endswith(".mscx") for name in names):
                raise ValueError("rewritten ZIP lost the score")

        if backup_dir:
            destination = backup_path_for(path, backup_dir, backup_base)
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                if sha256(destination) != sha256(path):
                    raise ValueError(f"existing backup differs: {destination}")
            else:
                shutil.copy2(path, destination)

        os.chmod(temporary_path, original_mode)
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def main() -> int:
    args = parse_args()
    if args.backup_dir and not args.dry_run:
        args.backup_dir = args.backup_dir.expanduser().resolve()
        args.backup_dir.mkdir(parents=True, exist_ok=True)
    if args.backup_base:
        args.backup_base = args.backup_base.expanduser().resolve()

    files = collect_db_files(args.paths)
    totals = {
        "files": len(files),
        "modified": 0,
        "font_replacements": 0,
        "pitch_remapped": 0,
        "audio_fixed": 0,
        "unchanged": 0,
        "failed": 0,
    }

    for path in files:
        try:
            entries, changes = prepare_archive(path)
            requires_write = (
                changes["font_replacements"] > 0
                or changes["pitch_remapped"] > 0
                or changes["audio_fixed"] > 0
            )
            if not requires_write:
                totals["unchanged"] += 1
                continue

            totals["modified"] += 1
            totals["font_replacements"] += changes["font_replacements"]
            totals["pitch_remapped"] += changes["pitch_remapped"]
            totals["audio_fixed"] += changes["audio_fixed"]
            if not args.quiet:
                print(
                    f"{'Would fix' if args.dry_run else 'Fixing'}: {path} "
                    f"(notes={changes['pitch_remapped']}, "
                    f"fonts={changes['font_replacements']}, "
                    f"audio={changes['audio_fixed']})"
                )
            if not args.dry_run:
                write_archive_atomic(path, entries, args.backup_dir, args.backup_base)
        except Exception as error:
            totals["failed"] += 1
            print(f"FAILED: {path}: {error}", file=sys.stderr)

    print(
        "Summary: "
        f"files={totals['files']} "
        f"modified={totals['modified']} "
        f"pitch_remapped={totals['pitch_remapped']} "
        f"font_replacements={totals['font_replacements']} "
        f"audio_fixed={totals['audio_fixed']} "
        f"unchanged={totals['unchanged']} "
        f"failed={totals['failed']} "
        f"dry_run={args.dry_run}"
    )
    return 1 if totals["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
