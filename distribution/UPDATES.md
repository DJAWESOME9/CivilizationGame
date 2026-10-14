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


## Published 0.2.9 / build 11 — 2026-10-13

Latest public release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.9
The top bar now shows +food/day beneath Food, using gross production before
consumption and spoilage. All six build 11 artifacts uploaded after RSA signature,
pack metadata and ZIP checksum verification. No gameplay or UI runtime tests run.

## Published 0.2.11 / build 13 — 2026-10-13

Latest public release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.11
The Build tab explains the Toolmaking → Shelter Building unlock path and provides
placement guidance after construction is available. All six release artifacts
were uploaded; feed signature, PCK hashes and ZIP checksums verified. No gameplay
or live updater test was run.


## Published 0.2.12 / build 14 — 2026-10-13

Latest public release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.12
Corrects three GDScript inference errors confirmed in the 0.2.11 startup log,
which prevented the main settlement scene from loading. All six release assets
were uploaded; update signature and PCK hashes verified, and GitHub ZIP/PCK
digests match local package values. No gameplay launch or multiplayer verification
was performed.


## Published 0.2.13 / build 15 — 2026-10-13

Includes the Build panel nested-tab layout correction, which gives the inner
building category tabs enough height to display their options, plus procedural
tree crown and river bank/shoreline visual improvements. Also includes the
already-published 0.2.12 startup parsing correction. All six artifacts were
published at https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.13.
Signed feed, PCK sizes/hashes, and ZIP checksums verified; no gameplay or live
updater test was run.


## Published 0.2.14 / build 16 — 2026-10-13

Published as Latest: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.14. Includes all pending worktree gameplay/UI changes: Town Hall policies/influence/happiness, configurable food response, pregnancy/recovery workforce exclusion, research points, starting-object dismantling, construction caps, army reserves/defense/messengers, 16 civilization slots/late joining/mixed AI, fields, river scouting and winter hex contrast. Mac/Windows ZIPs, both PCKs, signed update.json and checksums uploaded. Packaging completed; RSA signature, local pack sizes/hashes and ZIP checksums verified. No gameplay, live updater or multiplayer tests run. Source stays local under the private-source policy; the public repository receives release assets.


## 0.2.14 blank startup window correction — 2026-10-13

User screenshot shows a blank gray game window. Actual 20:08:58 startup log reports a GDScript parse error at settlement.gd:1523: cannot infer the type of absolute. The field corner array was untyped, so loop elements lacked a known Vector2 type. Changed corners to Array[Vector2]. This addresses the reported parse failure without changing game rules or saves. Published 0.2.15/build 17 as Latest: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.15. Both platform exports completed; signed feed, local sizes/hashes/checksums and all six GitHub asset sizes/digests verified. Packaging alone does not establish startup success. If the broken gray window cannot update, manually replace the app with the corrected ZIP; user data stays separate. No game launch or tests performed under the project rule.


## Multiplayer setup compilation and formatting correction — 2026-10-13

User screenshot shows literal %d in capacity heading, only Easy label, missing AI spinners and nonworking Host. Current startup log confirms multiplayer_session.gd LIMIT declaration fails as Warfare.SITES.size() is not a constant expression; ensuing null capacity prevents setup at the first spinner and leaves session unavailable. Replaced it with explicit integer capacity 16, aligned with the sixteen existing starting sites. Independent Easy/Medium/Hard counts and host callbacks remain the implemented flow; Resume preserves saved AI and disables new mix editing only when a world save exists.

Also corrected unsupported %g formatting in research costs and Town Hall influence/upkeep labels, matching repeated formatting errors in the log. Source/log inspection only; no launch, gameplay or multiplayer runtime test performed. Saves and identity unchanged.

Published 0.2.16/build 18 as Latest: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.16. Mac/Windows exports, signed feed and six assets published; signature and local/remote package sizes/hashes verified. No runtime hosting or UI verification performed.


## Published 0.2.18 / build 20 — 2026-10-14

Visible battles/casualties, raid loading/carried loot, live-sight rival inhabitants and home troops, settlement barter/scouting actions and dismantle-button reliability. Release: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.18. Both platform exports completed; signed feed, pack sizes/hashes and ZIP checksums verified. No gameplay, live updater or multiplayer runtime tests performed.


## Published 0.2.19 / build 21 — 2026-10-14

Published as Latest: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.19. Includes all pending seasonal, music/combat audio, research-tree, policy-grid, AI relationship/barter, training-cost, builder-assignment and map-caption changes. Both exports completed; signed feed, pack sizes/hashes and ZIP checksums verified. All six GitHub asset sizes and SHA-256 digests match local files; latest downloaded update.json byte-matches the signed local feed. Source committed locally; public repository receives release artifacts only. No gameplay, live updater or multiplayer runtime tests performed.


## Prepared 0.2.20 / build 22 — upload approval required — 2026-10-14

User requested commit and push. Per the project publishing convention, committed all pending source changes locally as 60b917e and prepared Mac/Windows packages, both platform PCKs, signed update.json and SHA256SUMS.txt. Includes tactical warfare, mixed armies, Attack/Raid/Raze, pursuit, surrender resource handover and return home without prisoners, physical fortifications, Arrow Slits, Fight back, script type fixes and sparse starting stone scenery. Public source push was not performed.

Exports completed; only the known nonfatal macOS system-certificate diagnostic appeared, with no script parse errors reported. RSA feed signature, PCK sizes/hashes and ZIP checksums verified locally. No gameplay, live updater or multiplayer tests performed.

Publication is blocked: automatic approval review rejected uploading the six compiled release/update assets because “commit and push” does not explicitly authorize this exact payload to the public GitHub destination. A release draft with v0.2.20, build 22 and release notes was saved at https://github.com/DJAWESOME9/CivilizationGame/releases/edit/untagged-4dee42706ce958ceea9c. No asset upload was performed. Prepared assets remain in dist; manifest saved in /tmp/civilization-release-22-manifest.json. Latest confirmed public release remains 0.2.19/build 21. Ask for explicit approval to upload/publish these six files to DJAWESOME9/CivilizationGame: Civilization-Mac.zip, Civilization-Windows.zip, Civilization-macOS-22.pck, Civilization-Windows-22.pck, update.json, SHA256SUMS.txt. Resume this draft after approval; do not rebuild unnecessarily or overwrite published assets.


## Published 0.2.20 / build 22 — 2026-10-14

User explicitly approved uploading/publishing all six prepared assets. Published as Latest: https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.20. Supersedes the pending upload-approval status above. Includes mixed armies, individual movement/health/melee/arrows with ±5% damage variance, Attack/Raid/Raze, optional raze demolition, capacity/load slowdown, casualty retreat/surrender and pursuit, no-prisoners surrender resource handover and return home, physical fortifications, Arrow Slits, Fight back, sparse stone scenery and script type fixes.

Source committed locally as 60b917e and ede5134; no private source push to the public repository. Both exports and script parsing completed. RSA feed signature, PCK sizes/hashes and ZIP checksums verified locally; all six public GitHub asset sizes and SHA-256 digests match local artifacts, and latest downloaded update.json byte-matches the signed local feed. Known nonfatal macOS system-certificate diagnostic only; no gameplay, balance, updater installation or multiplayer runtime tests performed. README/release records updated.
