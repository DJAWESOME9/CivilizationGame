# Obsidian note updates to apply

The Obsidian vault is outside the current filesystem write sandbox. These additions are preserved here for applying to the vault notes.

## Ideation.md

Append:

### Construction efficiency caps — 2026-10-13

Each building type has a maximum effective number of builders. Assigning more workers to construction than one unfinished building can use does not increase that site's speed; the excess builders continue to the next unfinished site. Caps may differ by building type to reflect the work involved. The initial per-type values are provisional balance choices and can be tuned through play feedback.

## Development.md

Under `## Current build`, append to the implementation bullets:

- Construction now limits effective builders per unfinished site by building type. Excess construction labor passes to later unfinished sites in placement order; seasonal and Carpentry modifiers still apply. Current caps are provisional balance values. Source inspection only; no tests or runtime checks were run.
