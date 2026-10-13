# Original Civilization audio

All WAV files in this folder are original procedural compositions and synthesized
sounds created for this project, with no external recordings or sampled music.
Rebuild them with `python3 scripts/generate_audio.py` (standard library only).

- settlement_music.wav: 64-second pentatonic plucked-string miniature with soft bass.
- woodland_ambience.wav: 24-second synthesized wind/water noise with bird-like tones.
- Remaining WAVs: button, construction, completion/harvest, research, scouting,
  warning and season cues.

The runtime duplicates the two background streams and enables full-length loops.
Separate Music, Ambience and Effects buses feed Master. Levels persist in local
settings. These sounds are a first audio pass; playback/listening has not been checked.
