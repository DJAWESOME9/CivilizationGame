"""Package already-exported builds for sharing; does not launch or test games."""
from pathlib import Path
import hashlib
import os
import shutil
import zipfile

project = Path(__file__).resolve().parent.parent
dist = project / "dist"
instructions = project / "distribution" / "START-HERE.txt"

mac = dist / "macOS"
windows = dist / "Windows"
if not (mac / "Civilization.app").is_dir() or not (windows / "Civilization.exe").is_file():
    raise SystemExit("Export both platforms with Build Packages.command first.")
for folder in (mac, windows):
    shutil.copyfile(instructions, folder / "START-HERE.txt")

mac_zip = dist / "Civilization-Mac.zip"
windows_zip = dist / "Civilization-Windows.zip"
# ZipInfo preserves Unix executable permissions; zipfile writes Unicode names
# with the UTF-8 flag, including the Mac executable's name in Info.plist.
for folder, destination in ((mac, mac_zip), (windows, windows_zip)):
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(folder.rglob("*")):
            relative = str(path.relative_to(dist))
            if path.is_symlink():
                info = zipfile.ZipInfo(relative)
                info.create_system = 3
                info.external_attr = path.lstat().st_mode << 16
                archive.writestr(info, os.readlink(path))
            else:
                archive.write(path, relative)
with (dist / "SHA256SUMS.txt").open("w") as checksum_file:
    for path in (mac_zip, windows_zip):
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        checksum = digest.hexdigest()
        checksum_file.write(f"{checksum}  {path.name}\n")
        print(f"Ready to share: {path} ({path.stat().st_size / 1024 / 1024:.1f} MB)")
