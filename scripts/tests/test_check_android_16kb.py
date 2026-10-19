import importlib.util
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "check_android_16kb.py"
SPEC = importlib.util.spec_from_file_location("check_android_16kb", SCRIPT)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


def elf(*headers, machine=183):
    data = bytearray(64)
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<H", data, 18, machine)
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, len(headers))
    for kind, flags, offset, address, size, alignment in headers:
        data.extend(struct.pack("<IIQQQQQQ", kind, flags, offset, address, 0,
                                size, size, alignment))
    return bytes(data)


class ElfTests(unittest.TestCase):
    def test_16k_and_64k_loads_pass_for_both_architectures(self):
        for machine in (62, 183):
            for alignment in (16384, 65536):
                with self.subTest(machine=machine, alignment=alignment):
                    _, errors = CHECK.check_elf(elf((1, 5, 0, 0, 128, alignment), machine=machine))
                    self.assertEqual(errors, [])

    def test_one_4k_load_in_an_otherwise_aligned_library_fails(self):
        _, errors = CHECK.check_elf(elf(
            (1, 5, 0, 0, 128, 16384),
            (1, 6, 0x1000, 0x1000, 128, 4096),
        ))
        self.assertTrue(any("alignment 4096" in error for error in errors))

    def test_incongruent_offsets_fail(self):
        _, errors = CHECK.check_elf(elf((1, 5, 0x1000, 0x2000, 128, 16384)))
        self.assertTrue(any("offsets differ" in error for error in errors))

    def test_dedicated_relro_load_passes(self):
        _, errors = CHECK.check_elf(elf(
            (1, 6, 0x680, 0x4680, 0x980, 16384),
            (0x6474E552, 4, 0x680, 0x4680, 0x980, 1),
            (1, 6, 0x4000, 0x8000, 128, 16384),
        ))
        self.assertEqual(errors, [])

    def test_relro_rounding_into_writable_data_fails(self):
        _, errors = CHECK.check_elf(elf(
            (1, 6, 0x680, 0x4680, 0x1980, 16384),
            (0x6474E552, 4, 0x680, 0x4680, 0x980, 1),
        ))
        self.assertTrue(any("RELRO" in error for error in errors))

    def test_32bit_library_is_not_subject_to_this_check(self):
        data = bytearray(elf((1, 5, 0, 0, 128, 4096), machine=40))
        data[4] = 1
        self.assertEqual(CHECK.check_elf(data), (None, []))

    def test_truncated_header_fails(self):
        with self.assertRaises(ValueError):
            CHECK.check_elf(elf((1, 5, 0, 0, 128, 16384))[:70])


class ArchiveTests(unittest.TestCase):
    def test_cli_rejects_bad_library_with_its_name(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "release.aab"
            name = "base/lib/arm64-v8a/libincompatible.so"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(name, elf((1, 5, 0, 0, 128, 4096)))
            result = subprocess.run([sys.executable, str(SCRIPT), str(path), "--require-native"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(name, result.stderr)

    def test_cli_rejects_archive_without_native_libraries(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "empty.aab"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("base/dex/classes.dex", b"not a native library")
            result = subprocess.run([sys.executable, str(SCRIPT), str(path), "--require-native"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("no arm64-v8a/x86_64", result.stderr)

    def test_corrupt_native_library_is_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "corrupt.aar"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("jni/arm64-v8a/libbroken.so", b"not ELF")
            count, errors = CHECK.check_archive(path)
            self.assertEqual(count, 0)
            self.assertTrue(any("libbroken.so" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
