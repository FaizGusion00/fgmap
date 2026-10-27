"""Muzik asli untuk video promosi FGMaps, dijana dengan numpy (tiada sampel/lesen pihak ketiga).

120 BPM, 1 bar = 2 s, progresi Am - F - C - G. Struktur mengikut babak video:
  s1 (tiada isyarat): pad malap + degupan jantung   s2: arpeggio + hi-hat   s3+: dram penuh (drop)
  s9 (penutup): hentaman + pad bersih + ekor.
Penggunaan:  python3 tools/promo/music.py --aspect 16x9 --out promo_out/audio/music_16x9.wav
"""
import argparse
import wave

import numpy as np

SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
TL = {
    "16x9": [("s1", 0, 4), ("s2", 4, 12), ("s3", 12, 22), ("s4", 22, 30), ("s5", 30, 36), ("s6", 36, 44), ("s7", 44, 48), ("s8", 48, 54), ("s9", 54, 60)],
    "9x16": [("s1", 0, 4), ("s2", 4, 8), ("s3", 8, 14), ("s4", 14, 18), ("s5", 18, 22), ("s8", 22, 26), ("s9", 26, 30)],
}
# bendera ciri setiap babak
FEAT = {
    "s1": dict(pad=.55, arp=0, hat=0, kick=0, bass=0, clap=0, heart=1),
    "s2": dict(pad=.7, arp=.6, hat=.5, kick=0, bass=0, clap=0, heart=0),
    "s3": dict(pad=.8, arp=.7, hat=1, kick=1, bass=1, clap=1, heart=0),
    "s4": dict(pad=.8, arp=.8, hat=1, kick=1, bass=1, clap=1, heart=0),
    "s5": dict(pad=.8, arp=.8, hat=1, kick=1, bass=1, clap=1, heart=0),
    "s6": dict(pad=.8, arp=.85, hat=1, kick=1, bass=1, clap=1, heart=0),
    "s7": dict(pad=.9, arp=.5, hat=.6, kick=.7, bass=.8, clap=0, heart=0),
    "s8": dict(pad=.9, arp=.7, hat=.8, kick=1, bass=1, clap=1, heart=0),
    "s9": dict(pad=1, arp=.55, hat=0, kick=0, bass=.6, clap=0, heart=0),
}
PROG = [(57, [57, 60, 64]), (53, [53, 57, 60]), (48, [48, 52, 55]), (55, [55, 59, 62])]  # akar, nada (MIDI)
mtof = lambda m: 440.0 * 2 ** ((m - 69) / 12)


def tone(f, n, harm=6, detune=0.0, phase=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for h in range(1, harm + 1):
        out += np.sin(2 * np.pi * f * h * (1 + detune) * t + phase * h) / h
    return out


def env(n, a, d, s=0.0, r=0.0):
    e = np.ones(n)
    na, nd = int(a * SR), int(d * SR)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nd and na + nd <= n:
        e[na:na + nd] = np.linspace(1, s, nd)
        e[na + nd:] = s
    if r:
        nr = min(n, int(r * SR))
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def put(buf, start, sig, gain=1.0, pan=0.0):
    i = int(start * SR)
    if i >= buf.shape[1]:
        return
    j = min(buf.shape[1], i + len(sig))
    sig = sig[: j - i] * gain
    buf[0, i:j] += sig * (1 - max(0, pan))
    buf[1, i:j] += sig * (1 + min(0, pan))


def fft_reverb(x, seconds=1.8, wet=.22, seed=3):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 6.5, n))
    ir[: int(.012 * SR)] *= np.linspace(0, 1, int(.012 * SR))
    ir /= np.sqrt((ir ** 2).sum())
    size = 1 << int(np.ceil(np.log2(x.shape[1] + n)))
    out = np.stack([np.fft.irfft(np.fft.rfft(c, size) * np.fft.rfft(ir, size), size)[: x.shape[1]] for c in x])
    return x * (1 - wet) + out * wet * 1.6


def fft_lowpass(x, hz=9000):
    size = x.shape[1]
    out = []
    for c in x:
        spec = np.fft.rfft(c)
        f = np.fft.rfftfreq(size, 1 / SR)
        spec *= 1 / (1 + (f / hz) ** 6)
        out.append(np.fft.irfft(spec, size))
    return np.stack(out)


def kick(n=int(.42 * SR)):
    t = np.arange(n) / SR
    f = 46 + 110 * np.exp(-t * 24)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7.5) * (1 + .6 * np.exp(-t * 60))


def hat(open_=False, seed=0):
    n = int((.26 if open_ else .06) * SR)
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(n)
    x = np.diff(x, prepend=0)                  # penapis laluan-tinggi kasar
    x = np.diff(x, prepend=0)
    return x * np.exp(-np.linspace(0, 1, n) * (7 if open_ else 26)) * .13


def clap(seed=1):
    n = int(.24 * SR)
    rng = np.random.default_rng(seed)
    x = np.diff(rng.standard_normal(n), prepend=0)
    e = np.exp(-np.linspace(0, 1, n) * 14)
    for k in (.0, .012, .024):
        e[int(k * SR):int(k * SR) + 400] += 1.2
    return x * e * .10


def whoosh(dur=.7, up=True, seed=5):
    n = int(dur * SR)
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(n)
    # "penapis" sapuan: tambah beberapa dengung sinus yang meluncur pada nada
    t = np.arange(n) / SR
    sweep = np.linspace(300, 3600, n) if up else np.linspace(3600, 300, n)
    tone_ = np.sin(2 * np.pi * np.cumsum(sweep) / SR)
    e = np.sin(np.linspace(0, np.pi, n)) ** 2
    return (np.diff(x, prepend=0) * .06 + tone_ * .09) * e


def impact(dur=1.6, seed=7):
    n = int(dur * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (38 + 60 * np.exp(-t * 8)) * t) * np.exp(-t * 2.6)
    rng = np.random.default_rng(seed)
    crash = np.diff(rng.standard_normal(n), prepend=0) * np.exp(-t * 3.6) * .08
    return boom * .9 + crash


def riser(dur=2.0, seed=9):
    n = int(dur * SR)
    rng = np.random.default_rng(seed)
    t = np.arange(n) / SR
    x = np.diff(rng.standard_normal(n), prepend=0) * .05
    sweep = np.cumsum(200 * 2 ** (np.linspace(0, 4, n))) / SR
    return (x + np.sin(2 * np.pi * sweep) * .08) * np.linspace(0, 1, n) ** 2


def pluck(f, n=int(.4 * SR)):
    t = np.arange(n) / SR
    return (tone(f, n, 4) * np.exp(-t * 9) + .35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 14)) * .5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aspect", default="16x9")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    tl = TL[a.aspect]
    dur = tl[-1][2]
    n = int(dur * SR)
    pad_b, arp_b, bass_b, drum_b, fx_b = (np.zeros((2, n)) for _ in range(5))
    duck = np.ones(n)

    def feat_at(t):
        for name, t0, t1 in tl:
            if t0 <= t < t1:
                return name, FEAT[name]
        return tl[-1][0], FEAT[tl[-1][0]]

    nb = int(dur / BEAT)
    # kick + sidechain, dram
    for b in range(nb):
        t = b * BEAT
        name, f = feat_at(t)
        if f["heart"] and b % 4 == 0:
            put(drum_b, t, kick(int(.3 * SR)) * .5, .6)
            put(drum_b, t + BEAT * .75, kick(int(.3 * SR)) * .3, .5)
        if f["kick"]:
            put(drum_b, t, kick(), .95 * f["kick"])
            i = int(t * SR); m = min(n, i + int(.28 * SR))
            duck[i:m] = np.minimum(duck[i:m], .38 + .62 * np.linspace(0, 1, m - i) ** 1.5)
        if f["clap"] and b % 2 == 1:
            put(drum_b, t, clap(b), .8)
        if f["hat"]:
            put(drum_b, t + BEAT / 2, hat(False, b), .8 * f["hat"], .15)
            if b % 4 == 3:
                put(drum_b, t + BEAT / 2, hat(True, b + 99), .7 * f["hat"], -.15)
            if f["hat"] >= 1 and b % 2 == 0:
                put(drum_b, t + BEAT / 4, hat(False, b + 7), .35, .2)
                put(drum_b, t + BEAT * .75, hat(False, b + 8), .35, -.2)

    # pad + bas + arpeggio mengikut bar
    nbar = int(np.ceil(dur / BAR))
    for bar in range(nbar):
        t = bar * BAR
        name, f = feat_at(t)
        root, notes = PROG[bar % 4]
        m = int(min(BAR + .6, dur - t + .6) * SR)
        for k, nn in enumerate(notes):
            sig = tone(mtof(nn), m, 5, .003 * (k - 1), k) + tone(mtof(nn), m, 5, -.004 * (k - 1), k + 1)
            sig *= env(m, .35, 0, 1, .55) * .075
            put(pad_b, t, sig, f["pad"], (k - 1) * .35)
        if f["bass"]:
            for e8 in range(8):
                tt = t + e8 * BEAT / 2
                if tt >= dur:
                    break
                nn = root - 12 + (12 if e8 in (3, 7) else 0) * (bar % 2)
                nlen = int(.24 * SR)
                s = np.sin(2 * np.pi * mtof(nn) * np.arange(nlen) / SR) + .25 * np.sin(4 * np.pi * mtof(nn) * np.arange(nlen) / SR)
                put(bass_b, tt, s * env(nlen, .004, .2, .3, .05) * .42, f["bass"])
        if f["arp"]:
            order = [0, 1, 2, 1, 0, 1, 2, 1, 2, 1, 0, 1, 2, 1, 0, 1]
            for s16 in range(16):
                tt = t + s16 * BEAT / 4
                if tt >= dur:
                    break
                nn = notes[order[s16]] + 12 * (1 if s16 % 4 == 3 else 0) + 12
                put(arp_b, tt, pluck(mtof(nn)), f["arp"] * (.55 + .45 * (s16 % 4 == 0)), -.4 + .8 * (s16 % 2))
    # kesan peralihan: whoosh pada setiap sempadan, hentaman pada drop dan penutup, riser sebelum drop
    for idx, (name, t0, t1) in enumerate(tl):
        if t0 > 0:
            put(fx_b, t0 - .5, whoosh(.7, True, idx), .8)
        if name in ("s3", "s9"):
            put(fx_b, t0, impact(), .9)
            put(fx_b, max(0, t0 - 2.0), riser(2.0, idx), .9)
        if name in ("s2",):
            for k in range(3):
                put(fx_b, t0 + 2.2 + k * .22, pluck(mtof(81 + 4 * k), int(.5 * SR)), .5, .0)
    # ekor akhir: nada penutup berdering
    for nn in (69, 76, 81, 84):
        s = tone(mtof(nn), int(2.4 * SR), 3) * env(int(2.4 * SR), .02, 2.2, 0, 0) * .07
        put(fx_b, dur - 4.0, s, 1.0, (nn % 3 - 1) * .3)

    music = pad_b + arp_b * 1.0 + fx_b * .8
    music = fft_reverb(music, 1.9, .24)
    bus = fft_lowpass(music * duck + bass_b * 1.0 + drum_b * 1.0, 8500)
    # fade masuk / keluar
    fin, fout = int(.08 * SR), int(1.8 * SR)
    bus[:, :fin] *= np.linspace(0, 1, fin)
    bus[:, -fout:] *= np.linspace(1, 0, fout) ** 1.5
    peak = np.abs(bus).max()
    bus = bus / peak * .89
    pcm = (np.clip(bus.T, -1, 1) * 32767).astype("<i2")
    with wave.open(a.out, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    print("ditulis", a.out, f"{dur}s", "puncak", round(float(peak), 3))


if __name__ == "__main__":
    main()
