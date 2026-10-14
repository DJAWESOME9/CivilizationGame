# Original Civilization audio

All WAV files in this folder are original procedural compositions and synthesized
sounds created for this project, with no external recordings or sampled music.
Rebuild them with `python3 scripts/generate_audio.py` (standard library only).

- settlement_music.wav: 64-second pentatonic plucked-string miniature with soft bass.
- woodland_ambience.wav: 24-second synthesized wind/water noise with bird-like tones.
- Remaining WAVs: button, construction, completion/harvest, research, scouting,
  warning and season cues.

River and hearth pieces expand the peaceful playlist to three tracks; battle drums and battle march provide two combat tracks. Battle clash, impact and arrow WAVs provide synthesized combat cues. Music cycles with four-second equal-power crossfades, switches for Fighting campaigns involving your army or home settlement, and returns afterward. Woodland ambience loops independently. Combat effects are intermittent presentation cues, not synchronized individual hits.
Separate Music, Ambience and Effects buses feed Master. Levels persist in local
settings. These sounds are a first audio pass; playback/listening has not been checked.
