# Publishing game updates

The public release repository is `DJAWESOME9/CivilizationGame`. It contains
downloadable binaries and signed update content; no source checkout, local saves,
identity files or signing secrets should be uploaded.

The first updater-enabled release is 0.2.0 / build 2. Friends with the earlier
ZIPs must replace their app once with an updater-enabled build. Subsequent game
updates download automatically at startup and apply the next time the app opens.
Settings has automatic updates, manual checks, downloads and restart controls.
Players can queue a restart during multiplayer; it runs automatically after
leaving the shared world.

## Build a new release

1. Increase `version` and the integer `build` in `distribution/release.json`.
   Build numbers must always increase. Match version fields in export_presets.cfg.
2. Keep `runtime` unchanged for compatible game/content updates. Changes to Godot,
   the bootstrap or native updater capabilities require a new native app download
   and a new runtime identifier. Keep the publisher public key stable.
3. Run `Build Packages.command`. It creates both app ZIPs, two platform game packs,
   the signed update.json, and ZIP checksums in dist. This builds, not tests, the game.
4. Create a draft GitHub release tagged `vVERSION`. Upload both ZIPs, the two PCK
   files, update.json and SHA256SUMS.txt. Wait for every upload to finish.
5. Publish the release and mark it latest. The fixed update URL is
   https://github.com/DJAWESOME9/CivilizationGame/releases/latest/download/update.json
   and the signed feed points to immutable assets under the version's tag.

Do not replace assets of an already published release. Make a new release instead.
The source-only repository has no CI upload credentials; later publication is an
explicit GitHub release step, not automatic on every local edit.

## How the updater works

The native bootstrap verifies RSA/SHA-256 signed metadata using the bundled public
key and verifies the downloaded pack's size and SHA-256 before mounting it. It loads
the approved pack before loading the main game scene. Packs are stored under
user://updates separately from saves and identity. The original app is kept intact.
Updates download during multiplayer and activate on restart after leaving a shared
world. Different game build numbers cannot join the same multiplayer world. Update failure leaves the existing
game playable; offline launches can use a previously downloaded, verified pack.

The signing key is `.tools/update-signing/private.pem`, excluded by Git and exports.
Back it up securely. Losing it requires redistributing native apps with a new public
key. Never put it in a release, public repository, client or chat. The key signature
authenticates game content; it does not replace Apple notarization/Windows signing.

To roll back an installed content update, close the game and rename
`updates/installed.json` in Godot's game user-data folder. The bundled app then loads
its original game. Saves and player identity remain in the parent user-data folder.
Restoring an older app/content version may not support newer save formats.

Updater source and release artifacts were inspected/built. No automated tests, live
update installation, platform game launches or remote multiplayer verification have
been performed under the project's current no-tests-without-request rule.


## Published 0.2.6 / build 8 — 2026-10-13

Latest public release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.6
Includes the Command tab selection fix and queued updater restart after leaving
a multiplayer world. All six release assets uploaded; signature, pack metadata
and ZIP hashes verified before publication. No gameplay or live updater test run.


## Published 0.2.7 / build 9 — 2026-10-13

Latest public release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.7
Adds vertical scrolling to all Command tab contents and nested building categories,
with tab headers remaining visible. Includes the Command tab selection fix and
queued multiplayer update restart. Six assets were uploaded after RSA signature,
pack metadata and ZIP checksum verification. No gameplay or live updater tests run.


## Published 0.2.8 / build 10 — 2026-10-13

Latest public release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.8
The People tab shows live counts for children (under 16), adults (16–64) and
elders (65+). Includes the scrollable Command panels and prior tab selection fix.
All six artifacts uploaded after signature, pack metadata and ZIP checksum checks.
No gameplay or runtime UI tests run.
