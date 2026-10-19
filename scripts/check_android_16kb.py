#!/usr/bin/env python3
"""Check arm64/x86_64 ELF libraries in an AAB, APK, AAR, or JAR.

Uses only the Python standard library. This checks ELF LOAD alignment and
RELRO overlap, not APK ZIP alignment or behavior on a 16 KB device. See
https://developer.android.com/guide/practices/page-sizes for the full checks.
"""

import argparse
from pathlib import Path
import struct
import sys
import zipfile

PAGE_SIZE = 16384
MACHINES = {62: "x86_64", 183: "arm64-v8a"}


def check_elf(data):
    """Return (ABI, errors); ABI is None for architectures not being checked."""
    if len(data) < 20 or data[:4] != b"\x7fELF":
        raise ValueError("not a valid ELF library")
    if data[5] != 1:
        raise ValueError("unsupported ELF byte order")
    machine = struct.unpack_from("<H", data, 18)[0]
    if machine not in MACHINES:
        return None, []
    if data[4] != 2 or len(data) < 64:
        raise ValueError("invalid ELF64 header")
    phoff = struct.unpack_from("<Q", data, 32)[0]
    phsize, phnum = struct.unpack_from("<HH", data, 54)
    if phsize < 56 or not phnum or phoff + phsize * phnum > len(data):
        raise ValueError("invalid ELF program-header table")

    loads, relros, errors = [], [], []
    for index in range(phnum):
        kind, flags, offset, address, _, _, size, alignment = struct.unpack_from(
            "<IIQQQQQQ", data, phoff + index * phsize
        )
        if kind == 1:  # PT_LOAD
            loads.append((flags, address, size))
            if alignment < PAGE_SIZE or alignment & (alignment - 1):
                errors.append(f"LOAD {index}: alignment {alignment} (need >=16384)")
            if (address - offset) % PAGE_SIZE:
                errors.append(f"LOAD {index}: file/virtual offsets differ modulo 16384")
        elif kind == 0x6474E552:  # PT_GNU_RELRO
            relros.append((address, size))
    if not loads:
        raise ValueError("ELF library has no LOAD segments")

    for address, size in relros:
        end = address + size
        protected_end = (end + PAGE_SIZE - 1) // PAGE_SIZE * PAGE_SIZE
        # RELRO in a dedicated LOAD is valid even if its end isn't page aligned.
        # Reject only when rounding up would also protect writable data.
        for flags, load_address, load_size in loads:
            if flags & 2 and max(end, load_address) < min(
                protected_end, load_address + load_size
            ):
                errors.append("RELRO end overlaps writable data on a 16 KB page")
                break
    return MACHINES[machine], errors


def check_archive(path):
    """Return (checked_library_count, error_messages)."""
    count, errors = 0, []
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            if not entry.filename.endswith(".so"):
                continue
            try:
                abi, issues = check_elf(archive.read(entry))
                if abi is None:
                    continue
                count += 1
                errors.extend(f"{entry.filename}: {issue}" for issue in issues)
            except (ValueError, struct.error) as error:
                errors.append(f"{entry.filename}: {error}")
    return count, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archives", nargs="+", type=Path)
    parser.add_argument("--require-native", action="store_true",
                        help="fail if an archive has no supported 64-bit libraries")
    args = parser.parse_args()
    failed = False
    for path in args.archives:
        try:
            count, errors = check_archive(path)
            if args.require_native and count == 0:
                errors.append("no arm64-v8a/x86_64 ELF libraries found")
            print(f"{path}: checked {count} 64-bit native libraries")
            for error in errors:
                print(f"  FAIL {error}", file=sys.stderr)
            failed |= bool(errors)
        except (OSError, ValueError, zipfile.BadZipFile, RuntimeError) as error:
            print(f"FAIL {path}: {error}", file=sys.stderr)
            failed = True
    if not failed:
        print("16 KB ELF checks passed. APK packaging and device testing remain separate.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
