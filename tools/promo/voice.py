"""Jana suara pencerita + masa setiap perkataan (untuk sarikata) daripada tools/promo/script.json.

Dijalankan oleh .github/workflows/promo-voice.yml (runner GitHub boleh mencapai perkhidmatan TTS,
persekitaran pembangunan tidak boleh). Keluaran: tools/promo/voice/<bahasa>/<suara>/<id>.mp3 dan
<id>.json ({"words": [[teks, mula_s, tempoh_s], ...], "duration": s}).

Perkhidmatan: edge-tts (suara neural Microsoft Edge, tidak rasmi). Sesuai untuk draf; untuk siaran
komersial akhir gantikan dengan suara sendiri atau TTS berlesen (Azure/ElevenLabs).
"""
import asyncio
import json
import pathlib
import sys

import edge_tts

ROOT = pathlib.Path(__file__).resolve().parent
SCRIPT = json.loads((ROOT / "script.json").read_text(encoding="utf-8"))


async def one(lang: str, which: str, line: dict) -> None:
    voice = SCRIPT["voices"][lang][which]
    out = ROOT / "voice" / lang / which
    out.mkdir(parents=True, exist_ok=True)
    com = edge_tts.Communicate(line["text"], voice, rate=SCRIPT["voices"][lang]["rate"], boundary="WordBoundary")
    audio = bytearray()
    words = []
    async for ch in com.stream():
        if ch["type"] == "audio":
            audio += ch["data"]
        elif ch["type"] == "WordBoundary":
            words.append([ch["text"], ch["offset"] / 1e7, ch["duration"] / 1e7])
    if not audio:
        raise SystemExit(f"tiada audio untuk {lang}/{which}/{line['id']}")
    (out / f"{line['id']}.mp3").write_bytes(bytes(audio))
    end = words[-1][1] + words[-1][2] if words else 0.0
    (out / f"{line['id']}.json").write_text(json.dumps({"words": words, "duration": end, "text": line["text"]}, ensure_ascii=False), encoding="utf-8")
    print(lang, which, line["id"], f"{end:.2f}s", len(words), "perkataan")


async def main() -> None:
    langs = sys.argv[1].split(",") if len(sys.argv) > 1 else ["ms", "en"]
    for lang in langs:
        for which in ("main", "alt"):
            for line in SCRIPT["lines"][lang]:
                for attempt in range(3):
                    try:
                        await one(lang, which, line)
                        break
                    except Exception as e:  # rangkaian sekali-sekala gagal
                        print("cuba semula", lang, which, line["id"], e)
                        await asyncio.sleep(2 * (attempt + 1))
                else:
                    raise SystemExit("gagal: " + line["id"])


asyncio.run(main())
