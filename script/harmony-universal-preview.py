"""Repackage the exact published Preview 1 unsigned debug HAPs for both ABIs.

GPL-3.0; see LICENSE. Not a general merger: input SHA256 pins prevent mixing
different source revisions, entrypoints, Flutter versions, or signed packages.
The x64 Ark bytecode is architecture-independent; Dart debug assets are equal.
Phone signing and device testing remain separate steps.
"""
import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

PINS = {
    "arm64": "7fe56b9106468c538df7568b3169c027af91ad7bb0aaba8ca0e9ff1c3bce8e36",
    "x64": "6ee9a2d8c1ff4f10965b7f88021e5d5b78f6867c482831f687b484b515d5e81d",
}
MANIFEST = "resources/rawfile/flutter_assets/NativeAssetsManifest.json"
LIBS = {"libflutter.so", "librust_lib_haka_comic.so", "libsqlite3.so", "libsqlite3_connection_pool.so"}


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = {arch: args.input_dir / f"haka-ohos-{arch}-debug-unsigned.hap" for arch in PINS}
    for arch, path in paths.items():
        if sha(path) != PINS[arch]:
            raise ValueError(f"Input is not the published Preview 1 {arch} artifact")
    if args.output.exists():
        raise ValueError("Output already exists; choose a new destination")
    with zipfile.ZipFile(paths["arm64"]) as arm, zipfile.ZipFile(paths["x64"]) as x64:
        # Verify all shared application assets, metadata, and license notices.
        allowed_differences = {MANIFEST, "pkgSdkInfo.json", "ets/modules.abc", "ets/sourceMaps.map"}
        shared_a = {n for n in arm.namelist() if not n.startswith("libs/")}
        shared_x = {n for n in x64.namelist() if not n.startswith("libs/")}
        if shared_a != shared_x:
            raise ValueError("Shared file sets differ")
        for name in shared_a - allowed_differences:
            if arm.read(name) != x64.read(name):
                raise ValueError(f"Shared application content differs: {name}")
        def normalize(data):
            return re.sub(rb"(@ohos\+flutter_ohos@)[a-z0-9=]+", rb"\1HASH", data)
        abc_a, abc_x = (normalize(z.read("ets/modules.abc")) for z in (arm, x64))
        # Panda checksum occupies bytes 8..11. The only other difference is
        # the OHPM cache hash embedded in source paths, not executable logic.
        if abc_a[:8] + abc_a[12:] != abc_x[:8] + abc_x[12:]:
            raise ValueError("Ark bytecode differs beyond checksum and cache paths")
        if json.loads(normalize(arm.read("ets/sourceMaps.map"))) != json.loads(normalize(x64.read("ets/sourceMaps.map"))):
            raise ValueError("Source mappings differ")
        for archive, abi, machine in ((arm, "arm64-v8a", 183), (x64, "x86_64", 62)):
            names = {n for n in archive.namelist() if n.startswith("libs/")}
            if names != {f"libs/{abi}/{lib}" for lib in LIBS}:
                raise ValueError(f"Unexpected libraries for {abi}")
            for name in names:
                data = archive.read(name)
                if data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != machine:
                    raise ValueError(f"Wrong ELF architecture: {name}")
        manifest = json.loads(x64.read(MANIFEST))
        arm_manifest = json.loads(arm.read(MANIFEST))
        if manifest["format-version"] != arm_manifest["format-version"]:
            raise ValueError("Native assets format differs")
        manifest["native-assets"].update(arm_manifest["native-assets"])
        sdk = json.loads(x64.read("pkgSdkInfo.json"))
        sdk["flutter_native_arm64_v8a"] = json.loads(arm.read("pkgSdkInfo.json"))["flutter_native_arm64_v8a"]
        replacements = {MANIFEST: json.dumps(manifest, separators=(",", ":")).encode(),
                        "pkgSdkInfo.json": json.dumps(sdk, separators=(",", ":")).encode()}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.output, "x") as out:
            for info in x64.infolist():
                out.writestr(info, replacements.get(info.filename, x64.read(info.filename)))
            for info in arm.infolist():
                if info.filename.startswith("libs/"):
                    out.writestr(info, arm.read(info.filename))
    with zipfile.ZipFile(args.output) as check:
        if check.testzip() is not None or len(check.namelist()) != len(set(check.namelist())):
            raise ValueError("Output ZIP integrity check failed")
    digest = sha(args.output)
    args.output.with_suffix(".hap.sha256").write_text(f"{digest}  {args.output.name}\n", encoding="utf-8")
    print(f"Created {args.output}\nSHA256 {digest}\nUnsigned debug package; device runtime NOT verified by this script.")


if __name__ == "__main__":
    main()
