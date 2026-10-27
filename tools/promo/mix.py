"""Campur audio akhir video promosi: suara pencerita + muzik (dikuncup di bawah suara) + kesan bunyi.

Masukan: garis masa JSON daripada enjin (render.mjs --timeline), fail suara tools/promo/voice/<bahasa>/<suara>/lNN.mp3.
Keluaran: WAV stereo 44.1 kHz (kelantangan akhir ditetapkan oleh mux.sh dengan loudnorm).

  python3 tools/promo/mix.py --timeline promo_out/timeline_16x9_ms.json --lang ms --out promo_out/audio/mix_16x9_ms.wav
"""
import argparse
import json
import pathlib
import subprocess
import wave

import numpy as np

import music as M

ROOT = pathlib.Path(__file__).resolve().parent
SR = M.SR

# ciri muzik setiap adegan (lihat music.FEAT)
F = lambda **k: dict(dict(pad=0, arp=0, hat=0, kick=0, bass=0, clap=0, heart=0), **k)
FEAT2 = {
    "s01": F(pad=.6, arp=.35, heart=1),
    "s02": F(pad=.7, arp=.6, hat=.4),
    "s03": F(pad=.7, arp=.65, hat=.6, kick=.5),
    "s04": F(pad=.8, arp=.75, hat=.9, kick=.9, bass=.8),
    "s05": F(pad=.8, arp=.75, hat=.9, kick=.9, bass=.8),
    "s06": F(pad=.8, arp=.7, hat=.8, kick=.8, bass=.8),
    "s07": F(pad=.85, arp=.8, hat=1, kick=1, bass=1, clap=1),
    "s08": F(pad=.8, arp=.55, hat=.5, kick=.5, bass=.7),
    "s09": F(pad=.8, arp=.7, hat=.8, kick=.8, bass=.8),
    "s10": F(pad=.9, arp=.5, hat=0, kick=0, bass=.4),
    "s11": F(pad=.85, arp=.8, hat=1, kick=1, bass=1, clap=1),
    "s12": F(pad=.85, arp=.7, hat=.6, kick=.6, bass=.7),
    "s13": F(pad=.85, arp=.8, hat=.9, kick=.9, bass=.9, clap=.8),
    "s14": F(pad=.9, arp=.8, hat=1, kick=1, bass=1, clap=1),
    "s15": F(pad=1, arp=.55, bass=.6),
}


def decode(path: pathlib.Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def envelope(x: np.ndarray, total: float) -> np.ndarray:
    """Sampul kuat suara pada 100 Hz (serangan cepat, lepasan perlahan), dinormalkan 0..1."""
    hop = SR // 100
    n = int(total * 100) + 1
    rms = np.zeros(n)
    for i in range(n):
        seg = x[i * hop:(i + 1) * hop * 2]
        rms[i] = np.sqrt((seg ** 2).mean()) if len(seg) else 0
    env = np.clip(rms / 0.05, 0, 1)
    out = np.zeros(n)
    cur = 0.0
    for i, v in enumerate(env):
        k = .55 if v > cur else .04          # serang pantas, lepas ~0.5 s
        cur += (v - cur) * k
        out[i] = cur
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeline", required=True)
    ap.add_argument("--lang", default="ms")
    ap.add_argument("--voice", default="main")
    ap.add_argument("--out", required=True)
    ap.add_argument("--no-music", action="store_true")
    a = ap.parse_args()
    tl = json.loads(pathlib.Path(a.timeline).read_text())
    total = tl["total"]
    n = int(total * SR)
    scenes = tl["scenes"]

    # suara
    voice = np.zeros(n)
    for s in scenes:
        for v in s["voice"]:
            x = decode(ROOT / "voice" / a.lang / a.voice / f"{v['id']}.mp3")
            i = int(v["start"] * SR)
            voice[i:i + len(x)] += x[: max(0, n - i)]
    rms = np.sqrt((voice[np.abs(voice) > 1e-4] ** 2).mean())
    voice *= (10 ** (-18 / 20)) / rms                      # suara ~ -18 dBFS RMS
    env = envelope(voice, total)
    duck = 1 - .62 * np.interp(np.arange(n) / SR, np.arange(len(env)) / 100, env)

    # muzik
    if a.no_music:
        music = np.zeros((2, n))
    else:
        bus = M.render([(s["id"], s["t0"], s["t1"]) for s in scenes], FEAT2)
        music = np.zeros((2, n)); m = min(n, bus.shape[1]); music[:, :m] = bus[:, :m]
        music *= .5 / np.abs(music).max() * duck

    # kesan bunyi: hentaman pada jenama, mula navigasi, kata kunci, penutup
    sfx = np.zeros((2, n))
    def put(t, sig, g=1.0):
        i = int(t * SR)
        if 0 <= i < n:
            j = min(n, i + len(sig)); sfx[0, i:j] += sig[: j - i] * g; sfx[1, i:j] += sig[: j - i] * g
    by = {s["id"]: s for s in scenes}
    put(by["s01"]["voice"][0]["start"] + 3.0, M.impact(1.4), .5)
    put(by["s07"]["t0"], M.impact(1.6), .55)
    put(by["s15"]["t0"], M.impact(1.8), .55)
    for s in scenes[1:]:
        put(s["t0"] - .22, M.whoosh(.55, True, hash(s["id"]) & 255), .8)

    out = voice[None, :] * np.array([[1.0], [1.0]]) * 1.0 + music + sfx * .6
    out /= max(1.0, np.abs(out).max() / .95)
    pcm = (np.clip(out.T, -1, 1) * 32767).astype("<i2")
    with wave.open(a.out, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    print("ditulis", a.out, f"{total:.1f}s")


if __name__ == "__main__":
    main()
