"""Create the signed update feed from exported game packs. Never uploads secrets."""
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

project = Path(__file__).resolve().parent.parent
dist = project / "dist"
release = json.loads((project / "distribution/release.json").read_text())
if not re.fullmatch(r"\d+\.\d+\.\d+", release["version"]):
    raise SystemExit("Use a numeric major.minor.patch release version.")
if not isinstance(release["build"], int) or release["build"] < 1:
    raise SystemExit("Use a positive integer build number.")
if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", release["repository"]):
    raise SystemExit("Specify the GitHub owner/repository in release.json.")
payload = {key: release[key] for key in ("version", "build", "runtime")}
payload["platforms"] = {}
base_url = f'https://github.com/{release["repository"]}/releases/download/v{release["version"]}'
for platform in ("macOS", "Windows"):
    pack = dist / f'Civilization-{platform}-{release["build"]}.pck'
    digest = hashlib.sha256()
    with pack.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    payload["platforms"][platform] = {
        "url": f"{base_url}/{pack.name}", "size": pack.stat().st_size,
        "sha256": digest.hexdigest(),
    }
raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
signing_dir = project / ".tools/update-signing"
payload_path = signing_dir / "payload.json"
signature_path = signing_dir / "signature.bin"
payload_path.write_bytes(raw)
subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(signing_dir / "private.pem"),
                "-out", str(signature_path), str(payload_path)], check=True)
envelope = {"payload": base64.b64encode(raw).decode(),
            "signature": base64.b64encode(signature_path.read_bytes()).decode()}
(dist / "update.json").write_text(json.dumps(envelope, indent=2) + "\n")
print(f'Signed update feed: {dist / "update.json"}')
