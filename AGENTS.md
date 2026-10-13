# Civilization project instructions

## Required context at the start of every chat

This is a native Godot civilization game, macOS first. The user maintains its
persistent design and development context in Obsidian. Do not rely on this chat
having the original conversation history.

Before planning or changing the game:

1. Read this file and `README.md` for project instructions and how to run it.
2. Read the Obsidian **Development.md** note for the current build and recent work.
3. Read **Ideation.md** for design intent and decisions relevant to the request.
   Check recent entries as well as the relevant earlier sections. Older entries
   describe historical states; later decisions can supersede them.
4. Inspect the implementation before treating a note as evidence of current behavior.

The Obsidian notes are real Markdown files in this vault folder:

`/Users/djfreeman/Library/Mobile Documents/iCloud~md~obsidian/Documents/DJ-Games/Civilization`

- **Design source:** `/Users/djfreeman/Library/Mobile Documents/iCloud~md~obsidian/Documents/DJ-Games/Civilization/Ideation.md`
- **Current development context:** `/Users/djfreeman/Library/Mobile Documents/iCloud~md~obsidian/Documents/DJ-Games/Civilization/Development.md`

Read these files directly through filesystem tools; an Obsidian connector is not
required. If the vault has moved or is unavailable, report that limitation and
locate it or ask for the new location. Do not silently skip the notes or create a
second vault as a substitute.

## Keep Obsidian updated

The user explicitly wants future chats to maintain these notes and has authorized
editing them and creating useful new notes in this Civilization vault folder.

- Record meaningful design decisions, requirements, corrections, and open questions
  in **Ideation.md** as the conversation progresses. Mark suggestions as tentative
  until accepted. Preserve useful history and explicitly mark superseded decisions.
- Update **Development.md** after meaningful implementation work: what exists now,
  how to use it, known limitations, and what was actually checked. Keep its current
  summary accurate; do not describe planned features as completed.
- Link additional notes using Obsidian `[[Note name]]` links when useful. Preserve
  the user's existing structure and unrelated edits.
- Update `README.md` when run instructions or user-facing controls change.
- Obsidian is outside the code workspace. Use the environment's approved filesystem
  write mechanism or escalation if required; authorization does not bypass sandbox
  restrictions. If a write is blocked, report it and preserve the proposed update.

## Where to work

| Area | Entry files |
| --- | --- |
| Main scene, camera, map, HUD, lighting | `main.tscn`, `scripts/settlement.gd` |
| Population, resources, construction, technology, time and saves | `scripts/simulation.gd` |
| Shared world clock, multiplayer commands and persistence | `scripts/multiplayer_session.gd` |
| Multiplayer menu and world setup | `scripts/multiplayer_screen.gd` |
| Warfare and commander controls | `scripts/warfare.gd`, `scripts/warfare_screen.gd` |
| Exploration, world entities and citizen visuals | `scripts/exploration.gd`, `scripts/world_entities.gd`, `scripts/citizens.gd` |
| Research UI and circular day clock | `scripts/research_screen.gd`, `scripts/day_clock.gd` |

Code is the source of truth for implemented behavior; Obsidian records intent and
continuity. Reconcile discrepancies when touching an affected system. Avoid
replacing saves, changing user-data files, or overwriting another chat's edits as
part of routine implementation work.

## Run and verification

- On macOS, launch `Launch.command`, or use
  `.tools/Godot.app/Contents/MacOS/Godot --path .` from this project folder.
- `Multiplayer Guest.command` opens a second local profile; see README for hosting.
- **Do not add or run tests unless the user requests testing or verification.**
- State precisely what was inspected or checked. Rendering a UI does not establish
  that multiplayer connections, combat, or shared clock synchronization work
  between machines.
