#!/usr/bin/env python3
"""Render radio speech clips with Piper (neural TTS) into audio/radio/<voice>/<md5(text)[:10]>.ogg.

Run after editing any line in radio.gd / mission.gd:
  godot --headless --path last-line -s tools/dump_voice.gd -- /tmp/clips.json
  python tools/gen_voice.py /tmp/clips.json <dir with the .onnx voices> last-line/audio/radio

Needs: pip install piper-tts soundfile numpy (Python 3.13 or older).
Voices (public-domain / CC0 / Apache datasets, see audio/radio/CREDITS.txt) come from
https://huggingface.co/rhasspy/piper-voices (en/en_US/<name>/medium/en_US-<name>-medium.onnx + .onnx.json).
Existing clips are skipped, so only new lines are rendered; delete a clip to re-render it.
"""
import hashlib, json, os, sys
import numpy as np
import soundfile as sf
from piper import PiperVoice, SynthesisConfig

MODELS = {  # voice id -> (piper model, length_scale)
    "hq": ("en_US-john-medium", 0.95),
    "squad": ("en_US-norman-medium", 1.0),
    "comms": ("en_US-kristin-medium", 0.95),
    "radar": ("en_US-bryce-medium", 0.95),
    "eo": ("en_US-ljspeech-medium", 0.95),
    "fire": ("en_US-joe-medium", 0.95),
}


def trim(a, sr):
    """Cut leading/trailing silence, keep a short pad."""
    idx = np.where(np.abs(a) > 0.01)[0]
    if len(idx) == 0:
        return a
    pad = int(0.03 * sr)
    return a[max(idx[0] - pad, 0): idx[-1] + pad]


def main(clips_json, model_dir, out_dir):
    clips = json.load(open(clips_json))
    for vid, texts in clips.items():
        model, scale = MODELS[vid]
        voice = PiperVoice.load(os.path.join(model_dir, model + ".onnx"))
        cfg = SynthesisConfig(length_scale=scale)
        os.makedirs(os.path.join(out_dir, vid), exist_ok=True)
        for text in texts:
            path = os.path.join(out_dir, vid, hashlib.md5(text.encode()).hexdigest()[:10] + ".ogg")
            if os.path.exists(path):
                continue
            chunks = list(voice.synthesize(text, syn_config=cfg))
            audio = np.concatenate([c.audio_float_array for c in chunks])
            sf.write(path, trim(audio, chunks[0].sample_rate), chunks[0].sample_rate, format="OGG", subtype="VORBIS")
        print(vid, model, len(texts), "clips")


if __name__ == "__main__":
    main(*sys.argv[1:4])
