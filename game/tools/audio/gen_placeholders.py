#!/usr/bin/env python3
"""Gera os sons PLACEHOLDER do M19 em game/art/_exemplo/audio/ (so stdlib; deterministico).

Uso: python game/tools/audio/gen_placeholders.py [pasta_de_saida]

Tudo mono, 8 bits, 11025 Hz, para ficar pequeno (o conjunto inteiro cabe em ~300 KB).
- musica_*.wav: laços de 4 s (2 compassos a 120 BPM) de acordes e arpejos. Cada nota termina dentro do proprio passo,
  entao o fim encaixa no comeco sem estalo.
- jingle_vitoria.wav / jingle_derrota.wav: 2 s e 2,4 s, tocados uma vez.
- sfx_*.wav: bipes, estalos e ruidos de 0,05 a 0,6 s.
A semente do ruido e fixa: rodar de novo gera arquivos identicos byte a byte.
Para trocar por sons de verdade, basta apontar o `stream` do SoundDef/MusicDef para o arquivo novo (os ids ficam).
"""
import math
import os
import random
import sys
import wave

RATE = 11025
SEED = 19


def hz(note: float) -> float:
    """Frequencia de uma nota MIDI (69 = La 440)."""
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def osc(kind: str, phase: float) -> float:
    """Onda de periodo 1 em [-1, 1]."""
    p = phase - math.floor(phase)
    if kind == "sine":
        return math.sin(2.0 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    raise ValueError(kind)


def tone(freq: float, dur: float, kind: str = "sine", attack: float = 0.005, release: float = 0.05,
         decay: float = 0.0, slide: float = 0.0, vol: float = 1.0) -> list:
    """Uma nota. `decay` > 0 apaga exponencialmente; `slide` e a variacao de frequencia (fracao) ao longo da nota."""
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1.0 + slide * (i / max(1, n)))
        phase += f / RATE
        env = 1.0
        if attack > 0 and t < attack:
            env = t / attack
        left = dur - t
        if release > 0 and left < release:
            env *= left / release
        if decay > 0:
            env *= math.exp(-t / decay)
        out.append(osc(kind, phase) * env * vol)
    return out


def noise(rng: random.Random, dur: float, attack: float = 0.002, release: float = 0.03, decay: float = 0.0,
          lowpass: float = 0.0, vol: float = 1.0) -> list:
    """Ruido branco; `lowpass` em (0, 1) suaviza (1 = sem filtro)."""
    n = int(dur * RATE)
    out = []
    prev = 0.0
    a = lowpass if lowpass > 0 else 1.0
    for i in range(n):
        t = i / RATE
        prev += a * (rng.uniform(-1.0, 1.0) - prev)
        env = 1.0
        if attack > 0 and t < attack:
            env = t / attack
        left = dur - t
        if release > 0 and left < release:
            env *= left / release
        if decay > 0:
            env *= math.exp(-t / decay)
        out.append(prev * env * vol)
    return out


def silence(dur: float) -> list:
    return [0.0] * int(dur * RATE)


def mix(*tracks: list) -> list:
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def seq(*parts: list) -> list:
    out: list = []
    for p in parts:
        out.extend(p)
    return out


def at(total: float, placed: list, wrap: bool = False) -> list:
    """Coloca (inicio_em_segundos, amostras) numa faixa de `total` segundos; o excedente e cortado ou, com `wrap`,
    volta ao comeco (laco sem emenda)."""
    n = int(total * RATE)
    out = [0.0] * n
    for start, samples in placed:
        s = int(start * RATE)
        for i, v in enumerate(samples):
            if s + i < n:
                out[s + i] += v
            elif wrap:
                out[(s + i) % n] += v
    return out


def write_wav(path: str, samples: list, peak: float = 0.8) -> None:
    """8 bits sem sinal, mono; normaliza para `peak`."""
    top = max(1e-9, max(abs(v) for v in samples))
    gain = peak / top if top > peak else 1.0
    data = bytearray()
    for v in samples:
        x = max(-1.0, min(1.0, v * gain))
        data.append(int(round(x * 127.0)) + 128)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


# ---------- musicas (4 s: 8 colcheias de 0,25 s... 16 passos de 0,25 s = 2 compassos de 4/4 a 120 BPM) ----------

STEP = 0.25
LOOP = 4.0


def arp_track(chords: list, pattern: list, kind: str, vol: float, note_len: float, octave: int = 0) -> list:
    """Arpejo: para cada passo de 0,25 s toca a nota `pattern[i]` (indice no acorde, -1 = pausa) do acorde do compasso."""
    placed = []
    for step in range(16):
        idx = pattern[step % len(pattern)]
        if idx < 0:
            continue
        chord = chords[step // 8]  # um acorde por compasso de 2 s
        note = chord[idx % len(chord)] + 12 * octave + 12 * (idx // len(chord))
        placed.append((step * STEP, tone(hz(note), note_len, kind, attack=0.004, release=0.04, decay=0.18, vol=vol)))
    return at(LOOP, placed, wrap=True)


def pad_track(chords: list, kind: str, vol: float) -> list:
    """Acorde sustentado por compasso; sobe e desce suave dentro do proprio compasso (fecha em zero nas pontas)."""
    placed = []
    for bar, chord in enumerate(chords):
        dur = 2.0
        layers = [tone(hz(n), dur, kind, attack=0.15, release=0.35, vol=vol) for n in chord]
        placed.append((bar * 2.0, mix(*layers)))
    return at(LOOP, placed, wrap=True)


def bass_track(roots: list, pattern: list, vol: float, note_len: float = 0.22) -> list:
    placed = []
    for step in range(16):
        if pattern[step % len(pattern)] == 0:
            continue
        root = roots[step // 8]
        placed.append((step * STEP, tone(hz(root), note_len, "tri", attack=0.004, release=0.04, decay=0.25, vol=vol)))
    return at(LOOP, placed, wrap=True)


def drum_track(rng: random.Random, kick: list, hat: list, vol: float) -> list:
    placed = []
    for step in range(16):
        if kick[step % len(kick)]:
            placed.append((step * STEP, tone(70.0, 0.15, "sine", attack=0.001, release=0.03, decay=0.06, slide=-0.5, vol=vol)))
        if hat[step % len(hat)]:
            placed.append((step * STEP, noise(rng, 0.05, attack=0.001, release=0.02, decay=0.02, vol=vol * 0.5)))
    return at(LOOP, placed, wrap=True)


def music(name: str, rng: random.Random) -> list:
    # acordes como listas de notas MIDI, um por compasso
    if name == "cidade":  # calma, maior: C - G
        chords = [[60, 64, 67], [55, 59, 62]]
        return mix(pad_track(chords, "sine", 0.22),
                   arp_track(chords, [0, 1, 2, 1, 2, 1, 0, -1], "tri", 0.30, 0.3, octave=1),
                   bass_track([48, 43], [1, 0, 0, 0, 1, 0, 0, 0], 0.30))
    if name == "estrada":  # caminhada, maior animado: F - C
        chords = [[53, 57, 60], [48, 52, 55]]
        return mix(pad_track(chords, "tri", 0.18),
                   arp_track(chords, [0, 2, 1, 2, 0, 2, 1, 2], "square", 0.12, 0.2, octave=1),
                   bass_track([41, 36], [1, 0, 1, 0], 0.30),
                   drum_track(rng, [1, 0, 0, 0, 0, 0, 0, 0], [0, 0, 1, 0], 0.35))
    if name == "masmorra":  # sombria, menor, esparsa: Am - Em
        chords = [[57, 60, 64], [52, 55, 59]]
        return mix(pad_track(chords, "saw", 0.10),
                   arp_track(chords, [0, -1, -1, 1, -1, -1, 2, -1], "sine", 0.35, 0.5, octave=1),
                   bass_track([45, 40], [1, 0, 0, 0, 0, 0, 0, 0], 0.35, 0.6))
    if name == "batalha":  # rapida, menor: Dm - Bb
        chords = [[62, 65, 69], [58, 62, 65]]
        return mix(pad_track(chords, "square", 0.08),
                   arp_track(chords, [0, 1, 2, 1], "square", 0.14, 0.18, octave=1),
                   bass_track([38, 34], [1, 1, 0, 1], 0.32, 0.18),
                   drum_track(rng, [1, 0, 1, 0, 1, 0, 0, 1], [1, 1, 1, 1], 0.42))
    if name == "chefe":  # pesada, menor, cromatica: Em - F
        chords = [[52, 55, 59], [53, 56, 60]]
        return mix(pad_track(chords, "saw", 0.12),
                   arp_track(chords, [0, 2, 1, 2, 0, 2, 1, 2], "saw", 0.12, 0.2, octave=1),
                   bass_track([40, 41], [1, 1, 0, 1, 1, 0, 1, 0], 0.38, 0.2),
                   drum_track(rng, [1, 0, 0, 1, 1, 0, 0, 0], [1, 1, 1, 1], 0.46))
    raise ValueError(name)


def jingle_vitoria() -> list:
    notes = [(60, 0.18), (64, 0.18), (67, 0.18), (72, 0.7)]
    out = []
    t = 0.0
    for n, d in notes:
        out.append((t, tone(hz(n), d + 0.1, "square", attack=0.004, release=0.08, vol=0.5)))
        t += d
    out.append((t, mix(*[tone(hz(n), 0.9, "tri", attack=0.01, release=0.4, vol=0.4) for n in (60, 64, 67, 72)])))
    return at(2.0, out)


def jingle_derrota() -> list:
    notes = [(64, 0.4), (62, 0.4), (60, 0.4), (55, 1.0)]
    out = []
    t = 0.0
    for n, d in notes:
        out.append((t, tone(hz(n), d + 0.1, "tri", attack=0.01, release=0.15, vol=0.6)))
        t += d
    return at(2.4, out)


# ---------- efeitos ----------

def sfx(name: str, rng: random.Random) -> list:
    if name == "menu_mover":
        return tone(880.0, 0.05, "square", attack=0.002, release=0.02, vol=0.5)
    if name == "menu_confirmar":
        return seq(tone(660.0, 0.06, "square", release=0.02, vol=0.5), tone(990.0, 0.1, "square", release=0.05, vol=0.5))
    if name == "menu_cancelar":
        return seq(tone(520.0, 0.06, "square", release=0.02, vol=0.5), tone(330.0, 0.1, "square", release=0.05, vol=0.5))
    if name == "texto":
        return tone(1200.0, 0.025, "square", attack=0.001, release=0.01, vol=0.35)
    if name == "bau":
        return seq(noise(rng, 0.06, decay=0.02, lowpass=0.3, vol=0.6),
                   tone(300.0, 0.12, "tri", release=0.05, slide=0.6, vol=0.5),
                   tone(600.0, 0.2, "tri", release=0.12, vol=0.5))
    if name == "porta":
        return mix(noise(rng, 0.4, attack=0.05, release=0.2, lowpass=0.12, vol=0.6),
                   tone(110.0, 0.4, "saw", attack=0.05, release=0.2, slide=-0.3, vol=0.25))
    if name == "passo":
        return noise(rng, 0.07, attack=0.001, release=0.03, decay=0.025, lowpass=0.2, vol=0.6)
    if name == "nivel":
        return seq(*[tone(hz(n), 0.1, "square", release=0.03, vol=0.45) for n in (72, 76, 79)],
                   tone(hz(84), 0.3, "square", release=0.2, vol=0.45))
    if name == "conjurar":
        return mix(tone(300.0, 0.45, "sine", attack=0.05, release=0.1, slide=2.0, vol=0.5),
                   noise(rng, 0.45, attack=0.1, release=0.1, lowpass=0.5, vol=0.15))
    if name == "golpe":
        return mix(noise(rng, 0.12, decay=0.04, vol=0.6),
                   tone(180.0, 0.12, "sine", release=0.04, decay=0.05, slide=-0.5, vol=0.6))
    if name == "acerto":
        return mix(noise(rng, 0.08, decay=0.025, vol=0.5),
                   tone(220.0, 0.1, "square", release=0.04, decay=0.04, slide=-0.4, vol=0.4))
    if name == "queda":
        return seq(tone(400.0, 0.4, "tri", release=0.1, slide=-0.8, vol=0.55),
                   noise(rng, 0.15, decay=0.05, lowpass=0.2, vol=0.4))
    if name == "reacao":
        return mix(tone(500.0, 0.3, "saw", release=0.1, slide=1.2, vol=0.3),
                   noise(rng, 0.3, attack=0.01, release=0.15, decay=0.12, lowpass=0.6, vol=0.35))
    if name == "estado":
        return seq(tone(700.0, 0.07, "tri", release=0.02, vol=0.5), tone(560.0, 0.07, "tri", release=0.02, vol=0.5),
                   tone(700.0, 0.07, "tri", release=0.03, vol=0.5))
    if name == "item":
        return seq(tone(hz(79), 0.07, "sine", release=0.02, vol=0.5), tone(hz(84), 0.2, "sine", release=0.12, vol=0.5))
    raise ValueError(name)


MUSICAS = ["cidade", "estrada", "masmorra", "batalha", "chefe"]
SFX = ["menu_mover", "menu_confirmar", "menu_cancelar", "texto", "bau", "porta", "passo", "nivel",
       "conjurar", "golpe", "acerto", "queda", "reacao", "estado", "item"]


def generate(out_dir: str) -> list:
    os.makedirs(out_dir, exist_ok=True)
    written = []

    def put(name: str, samples: list) -> None:
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, samples)
        written.append(path)

    for m in MUSICAS:
        put("musica_" + m, music(m, random.Random(SEED)))
    put("jingle_vitoria", jingle_vitoria())
    put("jingle_derrota", jingle_derrota())
    for s in SFX:
        put("sfx_" + s, sfx(s, random.Random(SEED)))
    return written


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    default = os.path.normpath(os.path.join(here, "..", "..", "art", "_exemplo", "audio"))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else default
    files = generate(out_dir)
    total = sum(os.path.getsize(f) for f in files)
    print("%d arquivos em %s (%d bytes)" % (len(files), out_dir, total))


if __name__ == "__main__":
    main()
