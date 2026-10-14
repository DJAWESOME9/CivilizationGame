"""Rebuild the project's original synthesized audio. Python standard library only."""
import math
import random
import wave
from array import array
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
ROOT.mkdir(parents=True, exist_ok=True)
rng = random.Random(731)

def tone(samples, start, duration, frequency, gain, kind='pluck'):
    offset = int(start * RATE)
    for j in range(int(duration * RATE)):
        if offset + j >= len(samples):
            break
        t = j / RATE
        phase = 2 * math.pi * frequency * t
        attack = min(1, t / 0.025)
        tail = min(1, (duration - t) / 0.15)
        envelope = attack * max(0, tail) * math.exp(-t * (3.2 if kind == 'pluck' else 0.65))
        value = math.sin(phase) + (0.3 if kind == 'pluck' else 0.12) * math.sin(phase * 2) + 0.08 * math.sin(phase * 3)
        samples[offset + j] += value * gain * envelope

def write(name, samples):
    pcm = array('h', (int(max(-1, min(1, x)) * 32767) for x in samples))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())

# 64-second pentatonic miniature: warm plucked strings and a soft low drone.
music = array('f', [0]) * (RATE * 64)
progression = [(146.83, 220, 293.66), (130.81, 196, 261.63), (110, 164.81, 220), (130.81, 196, 293.66)]
melody = [440, 392, 329.63, 293.66, 329.63, 392, 293.66, 220,
          293.66, 329.63, 440, 392, 329.63, 293.66, 220, 293.66]
for bar in range(16):
    chord = progression[(bar // 2) % 4]
    tone(music, bar * 4, 3.8, chord[0] / 2, 0.07, 'soft')
    for beat in range(4):
        tone(music, bar * 4 + beat, 2.0, chord[beat % 3], 0.095)
    tone(music, bar * 4 + 0.5, 2.5, melody[bar], 0.08)
# Smooth silent seam, allowing continuous looping without clicks.
for i in range(RATE):
    music[i] *= i / RATE
    music[-1-i] *= i / RATE
write('settlement_music', music)

ambience = array('f', [0]) * (RATE * 24)
filtered = 0.0
for i in range(len(ambience)):
    t = i / RATE
    filtered = filtered * 0.97 + rng.uniform(-1, 1) * 0.03
    seam = min(1, t / 1.5, (24 - t) / 1.5)
    ambience[i] = (filtered * 0.22 + rng.uniform(-1, 1) * 0.018) * (0.75 + 0.2 * math.sin(t * 0.6)) * seam
for start in [2.4, 6.8, 13.1, 18.5]:
    for chirp in range(3):
        tone(ambience, start + chirp * 0.18, 0.12, 1800 + chirp * 230, 0.035, 'soft')
write('woodland_ambience', ambience)

for name, notes, length in [
    ('click', [(0, 0.10, 740, 0.14)], 0.15),
    ('build', [(0, 0.16, 130.81, 0.24), (0.12, 0.2, 196, 0.18)], 0.4),
    ('complete', [(0, 0.4, 293.66, 0.2), (0.14, 0.4, 369.99, 0.17), (0.28, 0.7, 440, 0.15)], 1.1),
    ('research', [(0, 0.6, 440, 0.17), (0.18, 0.6, 587.33, 0.15), (0.36, 1, 880, 0.12)], 1.5),
    ('scout', [(0, 0.4, 392, 0.17), (0.2, 0.6, 523.25, 0.15)], 0.9),
    ('alert', [(0, 0.35, 220, 0.19), (0.38, 0.4, 174.61, 0.19)], 0.9),
    ('season', [(0, 0.8, 293.66, 0.16), (0.2, 0.8, 392, 0.13)], 1.2),
]:
    samples = array('f', [0]) * int(RATE * length)
    for note in notes:
        tone(samples, *note)
    write(name, samples)

# Additional original pieces share a tonal palette for gentle crossfades.
def percussion(samples, start, gain, metallic=False):
    offset = int(start * RATE)
    duration = 0.38 if metallic else 0.28
    for j in range(int(duration * RATE)):
        if offset + j >= len(samples): break
        t = j / RATE
        envelope = min(1, t / 0.004) * math.exp(-t * (15 if metallic else 20))
        value = (rng.uniform(-1, 1) * 0.45 + math.sin(2 * math.pi * (930 if metallic else 85) * t)
                 + 0.3 * math.sin(2 * math.pi * (1433 if metallic else 53) * t))
        samples[offset + j] += value * gain * envelope

for name, battle, variant in [('river_music', False, 1), ('hearth_music', False, 2),
                              ('battle_drums', True, 0), ('battle_march', True, 1)]:
    samples = array('f', [0]) * (RATE * 64)
    for bar in range(16):
        chord = progression[(bar // 2 + variant) % 4]
        tone(samples, bar * 4, 3.9, chord[0] / 2, 0.085, 'soft')
        for beat in range(4):
            tone(samples, bar * 4 + beat, 1.8, chord[(beat + variant) % 3], 0.08)
            if battle:
                percussion(samples, bar * 4 + beat, 0.16 if beat % 2 == 0 else 0.09)
                tone(samples, bar * 4 + beat + 0.5, 0.65, chord[beat % 3], 0.06)
        tone(samples, bar * 4 + 0.5, 2.5, melody[(bar * (3 if variant == 2 else 1) + variant * 4) % 16],
             0.065 if battle else 0.085, 'soft' if variant == 1 else 'pluck')
    for i in range(int(RATE * 0.05)):
        samples[i] *= i / (RATE * 0.05)
        samples[-1-i] *= i / (RATE * 0.05)
    write(name, samples)

for name, metallic in [('battle_clash', True), ('battle_impact', False)]:
    samples = array('f', [0]) * int(RATE * 0.5)
    percussion(samples, 0, 0.3, metallic)
    write(name, samples)
samples = array('f', [0]) * int(RATE * 0.65)
for i in range(int(RATE * 0.35)):
    t = i / RATE
    samples[i] = rng.uniform(-1, 1) * 0.13 * math.sin(math.pi * t / 0.35) ** 2
percussion(samples, 0.38, 0.18)
write('battle_arrow', samples)
