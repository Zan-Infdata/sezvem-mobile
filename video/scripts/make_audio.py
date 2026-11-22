"""Synthesizes the v2 soundtrack: a music bed that follows the story beats in
src/v2/timeline.json, plus UI, monitor and character sound effects.

Everything is generated from code with a fixed seed, so the audio is
reproducible and license-free. Run from the video/ folder:

    python3 scripts/make_audio.py
"""

import json
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "public", "audio")
rng = np.random.default_rng(7)


# ---------- helpers ----------
def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, a=0.01, r=0.1, hold=None):
    """Linear attack, hold, exponential-ish release, over n samples."""
    e = np.ones(n)
    na = max(1, int(a * SR))
    nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    if hold is not None:
        end = min(n, na + int(hold * SR))
        e[end:] = 0
        rel = np.linspace(1, 0, nr) ** 2
        e[end : end + nr] = rel[: max(0, min(nr, n - end))]
    else:
        e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def lp(x, cutoff, order=2):
    sos = butter(order, min(cutoff, SR / 2 - 100), btype="low", fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


def hp(x, cutoff, order=2):
    sos = butter(order, cutoff, btype="high", fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


def bp(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


def stereo(x, width=0.0):
    if x.ndim == 2:
        return x
    if width <= 0:
        return np.stack([x, x], axis=1)
    d = int(width * SR)
    r = np.concatenate([np.zeros(d), x[:-d]]) if d else x
    return np.stack([x, r], axis=1)


_IR_CACHE = {}


def reverb(x, decay=1.6, wet=0.25, length=2.8):
    key = (decay, length)
    if key not in _IR_CACHE:
        t = t_axis(length)
        irs = []
        for _ in range(2):
            n = rng.standard_normal(len(t)) * np.exp(-t * (6.9 / decay))
            irs.append(lp(n, 6000) * 0.08)
        _IR_CACHE[key] = irs
    irs = _IR_CACHE[key]
    x = stereo(x)
    out = np.zeros((len(x) + len(irs[0]) - 1, 2))
    for c in range(2):
        out[:, c] = fftconvolve(x[:, c], irs[c])
    out[: len(x)] = out[: len(x)] * wet + x * (1 - wet)
    out[len(x) :] *= wet
    return out


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def save(name, x, peak=0.8):
    x = stereo(x)
    x = norm(x, peak)
    # Short fade at both ends against clicks.
    f = min(len(x) // 4, int(0.004 * SR))
    if f > 0:
        x[:f] *= np.linspace(0, 1, f)[:, None]
        x[-f:] *= np.linspace(1, 0, f)[:, None]
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def mix_at(buf, x, start_sec, gain=1.0):
    x = stereo(x)
    s = int(start_sec * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(x))
    buf[s:e] += x[: e - s] * gain


# ---------- instruments ----------
def saw(f, t, bright=1.0):
    out = np.zeros_like(t)
    k = 1
    while k * f < 7000 * bright and k <= 24:
        out += np.sin(2 * np.pi * k * f * t + k * 0.7) / k
        k += 1
    return out


def pad_voice(midi, sec, attack=1.2, release=1.6, cutoff=1800, bright=0.6):
    t = t_axis(sec + release)
    f = hz(midi)
    v = sum(saw(f * 2 ** (c / 1200), t, bright) for c in (-7, 0, 7)) / 3
    v = lp(v, cutoff)
    e = env(len(t), a=attack, r=release, hold=sec - attack)
    return v * e


def pad(chord, sec, **kw):
    left = sum(pad_voice(m, sec, **kw) for m in chord[::2])
    right = sum(pad_voice(m, sec, **kw) for m in chord[1::2]) if len(chord) > 1 else left
    n = max(len(left), len(right)) if not np.isscalar(right) else len(left)
    out = np.zeros((n, 2))
    out[: len(left), 0] += left
    out[: len(left), 1] += left * 0.55
    if not np.isscalar(right):
        out[: len(right), 1] += right
        out[: len(right), 0] += right * 0.55
    return out / max(1, len(chord)) * 1.6


def pluck(midi, sec=1.2, bright=1.0, decay=3.0):
    t = t_axis(sec)
    f = hz(midi)
    x = np.zeros_like(t)
    for k in range(1, 7):
        x += np.sin(2 * np.pi * k * f * t) * np.exp(-t * (decay + k * 2.2 / bright)) / k**1.3
    a = int(0.003 * SR)
    x[:a] *= np.linspace(0, 1, a)
    return x


def bell(midi, sec=2.5):
    t = t_axis(sec)
    f = hz(midi)
    x = (
        np.sin(2 * np.pi * f * t) * np.exp(-t * 1.6)
        + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 3)
        + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 5)
    )
    a = int(0.002 * SR)
    x[:a] *= np.linspace(0, 1, a)
    return x


def kick(sec=0.45, f0=110, f1=42):
    t = t_axis(sec)
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7)


def noise(sec):
    return rng.standard_normal(int(sec * SR))


def riser(sec, lo=300, hi=6000):
    n = noise(sec)
    t = t_axis(sec)
    out = np.zeros_like(n)
    steps = 40
    seg = len(n) // steps
    for i in range(steps):
        fc = lo * (hi / lo) ** (i / steps)
        s = slice(i * seg, (i + 1) * seg if i < steps - 1 else len(n))
        out[s] = bp(n, fc * 0.7, min(fc * 1.4, SR / 2 - 200))[s]
    return out * (t / sec) ** 2


# ---------- music ----------
def arp(chord, sec, step, octave=12, gain=0.35, bright=1.0, pattern=(0, 1, 2, 3, 2, 1)):
    out = np.zeros((int((sec + 1.5) * SR), 2))
    i = 0
    tt = 0.0
    while tt < sec:
        m = chord[pattern[i % len(pattern)] % len(chord)] + octave
        p = pluck(m, 1.2, bright) * gain * (0.85 + 0.15 * ((i % 4) == 0))
        pan = 0.5 + 0.3 * np.sin(i * 1.3)
        mix_at(out, np.stack([p * (1 - pan) * 2, p * pan * 2], axis=1) * 0.5, tt)
        tt += step
        i += 1
    return out


def section(kind, sec, events):
    """Renders one music section of `sec` seconds (+ tail)."""
    tail = 2.5
    buf = np.zeros((int((sec + tail) * SR), 2))
    if kind == "intro":
        chords = [[45, 57, 60, 64, 71], [41, 57, 60, 64, 67]]
        half = sec / 2
        for i, c in enumerate(chords):
            mix_at(buf, pad(c, half + 0.4, attack=1.4, cutoff=1500), i * half, 0.9)
        for k, (m, at) in enumerate([(76, 0.6), (71, 1.8), (72, half + 0.3), (79, half + 1.6)]):
            mix_at(buf, pluck(m, 2.0, 0.8, 2.0), at, 0.22)
    elif kind == "app":
        bar = 2.5
        prog = [[48, 55, 59, 62, 64], [43, 55, 59, 62, 64], [45, 55, 60, 64, 67], [41, 53, 57, 60, 64]]
        i = 0
        tt = 0.0
        while tt < sec:
            c = prog[i % 4]
            d = min(bar, sec - tt)
            mix_at(buf, pad(c[1:], d + 0.3, attack=0.6, release=1.2, cutoff=1600), tt, 0.55)
            mix_at(buf, pad([c[0] - 12], d + 0.3, attack=0.3, release=0.8, cutoff=300, bright=0.3), tt, 0.5)
            mix_at(buf, arp(c[1:], d, 0.3125, octave=12, gain=0.28), tt, 1.0)
            tt += bar
            i += 1
    elif kind == "tension":
        mix_at(buf, pad([38, 50, 57], sec + 0.5, attack=1.0, cutoff=700, bright=0.4), 0, 0.9)
        mix_at(buf, pad([62, 65, 70], sec + 0.5, attack=2.5, cutoff=1400), 0, 0.35)
        # A slow heartbeat thump that speeds up with the rising monitor.
        tt = 1.2
        gap = 1.0
        while tt < sec - 0.2:
            mix_at(buf, kick(0.4, 90, 40), tt, 0.5)
            mix_at(buf, kick(0.35, 80, 40), tt + 0.18, 0.3)
            tt += gap
            gap = max(0.48, gap * 0.9)
        mix_at(buf, riser(sec - 1.0, 200, 5000), 1.0, 0.12)
    elif kind == "alert":
        half = sec / 2
        mix_at(buf, pad([40, 52, 54, 59, 66], half + 0.6, attack=1.2, cutoff=1100), 0, 0.75)
        mix_at(buf, pad([36, 52, 55, 62, 67], sec - half - events.get("pause", 0) + 0.2, attack=1.0, cutoff=1200), half, 0.75)
        # Soft clock pulse.
        tt = 0.0
        end = sec - events.get("pause", 0)
        i = 0
        while tt < end:
            p = pluck(83 if i % 2 == 0 else 78, 0.25, 1.4, 12) * (0.13 if i % 2 == 0 else 0.08)
            mix_at(buf, p, tt)
            tt += 0.5
            i += 1
        if "urgent" in events:
            mix_at(buf, riser(1.2, 400, 6000), events["urgent"] - 1.2, 0.18)
            mix_at(buf, kick(0.9, 70, 30), events["urgent"], 0.8)
            mix_at(buf, pad([40, 47, 52, 55, 58], 2.2, attack=0.05, release=1.8, cutoff=1600), events["urgent"], 0.5)
    elif kind == "warm":
        bar = 2.4
        prog = [[50, 62, 66, 69, 73], [47, 62, 66, 69, 74], [43, 59, 62, 66, 71], [45, 61, 64, 69, 71]]
        i = 0
        tt = 0.0
        while tt < sec:
            c = prog[i % 4]
            d = min(bar, sec - tt)
            mix_at(buf, pad(c[1:], d + 0.3, attack=0.5, release=1.2, cutoff=2200), tt, 0.5)
            mix_at(buf, pad([c[0] - 12], d + 0.3, attack=0.2, release=0.8, cutoff=300, bright=0.3), tt, 0.45)
            mix_at(buf, arp(c[1:], d, 0.3, octave=12, gain=0.3, bright=1.3, pattern=(0, 2, 1, 3, 2, 4)), tt, 1.0)
            tt += bar
            i += 1
    elif kind == "swell":
        p = pad([43, 55, 59, 62, 66, 69], sec + 0.4, attack=sec * 0.7, release=1.5, cutoff=2400)
        mix_at(buf, p, 0, 1.0)
        mix_at(buf, bell(78, 3.0), 0.4, 0.12)
        mix_at(buf, bell(83, 3.0), 1.8, 0.1)
    elif kind == "playful":
        prog = [[48, 60, 64, 67, 72], [53, 60, 65, 69, 72]]
        half = sec / 2
        for i, c in enumerate(prog):
            mix_at(buf, pad(c[1:], half + 0.3, attack=0.3, release=1.0, cutoff=2400), i * half, 0.45)
            mix_at(buf, arp(c[1:], half, 0.1667, octave=12, gain=0.25, bright=1.5, pattern=(0, 1, 2, 3, 4, 3, 2, 1)), i * half, 1.0)
            for b in np.arange(0, half, 0.6667):
                mix_at(buf, kick(0.3, 120, 50), i * half + b, 0.35)
    elif kind == "finale":
        logo = events["logo"]
        mix_at(buf, riser(logo - 0.2, 200, 8000), 0.2, 0.22)
        mix_at(buf, kick(1.4, 80, 32), logo, 1.0)
        chord = [36, 48, 55, 59, 62, 64, 67]
        mix_at(buf, pad(chord, sec - logo, attack=0.08, release=2.0, cutoff=2600), logo, 1.1)
        for k, m in enumerate([72, 76, 79, 83, 86]):
            mix_at(buf, bell(m, 3.0), logo + 0.15 + k * 0.12, 0.16)
        # Fade the whole section out as the circle closes.
        close = events["close"]
        n = len(buf)
        g = np.ones(n)
        a = int(close * SR)
        b = min(n, int((close + events["close_len"]) * SR))
        g[a:b] = np.linspace(1, 0, b - a) ** 1.5
        g[b:] = 0
        buf *= g[:, None]
        return buf
    return buf


# Evens out loudness between sections while keeping the story's dynamics.
SECTION_GAIN = {"intro": 1.7, "alert": 1.35, "swell": 1.3, "playful": 1.7, "finale": 1.15}


def music(timeline, cues):
    fps = timeline["fps"]
    tr = timeline["transition"]
    starts = []
    acc = 0
    for i, s in enumerate(timeline["scenes"]):
        starts.append(acc)
        acc += s["duration"] - tr
    total = (acc + tr) / fps
    # Merge consecutive scenes with the same music section.
    sections = []
    for i, s in enumerate(timeline["scenes"]):
        st = starts[i] / fps
        end = (starts[i] + s["duration"]) / fps
        if sections and sections[-1]["kind"] == s["music"]:
            sections[-1]["end"] = end
        else:
            sections.append({"kind": s["music"], "start": st, "end": end, "first": s["id"]})
    buf = np.zeros((int((total + 3) * SR), 2))
    for sec in sections:
        dur = sec["end"] - sec["start"]
        ev = {}
        if sec["kind"] == "alert":
            crit = starts[[s["id"] for s in timeline["scenes"]].index("critical")] / fps
            ev = {"urgent": crit + cues["urgent"] / fps - sec["start"], "pause": cues["pause"] / fps}
        if sec["kind"] == "finale":
            ev = {"logo": cues["logo"] / fps, "close": cues["close"] / fps, "close_len": cues["close_len"] / fps}
        x = section(sec["kind"], dur, ev) * SECTION_GAIN.get(sec["kind"], 1.0)
        # Short crossfade in so sections blend.
        fi = int(0.35 * SR)
        x[:fi] *= np.linspace(0, 1, fi)[:, None]
        mix_at(buf, x, sec["start"])
    buf = buf[: int(total * SR)]
    buf = reverb(buf, decay=2.2, wet=0.3)[: int(total * SR)]
    return buf


# ---------- sound effects ----------
def sfx():
    # Whooshes for scene transitions and text.
    for name, sec, lo, hi, g in [("whoosh", 0.8, 300, 4000, 1.0), ("whoosh_soft", 1.1, 200, 2200, 0.7)]:
        n = noise(sec)
        t = t_axis(sec)
        e = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 2
        x = riser(sec, lo, hi) * 0 + bp(n, lo, hi) * e
        save(name, reverb(x * g, 0.8, 0.3), 0.7)
    # Low hit for emphasised text and "Now".
    x = kick(1.2, 70, 30) + lp(noise(1.2), 400) * np.exp(-t_axis(1.2) * 6) * 0.3
    save("hit", reverb(x, 1.5, 0.35), 0.85)
    # UI tap.
    t = t_axis(0.06)
    x = np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 90) + hp(noise(0.06), 3000) * np.exp(-t * 140) * 0.4
    save("tap", x, 0.6)
    # Scan sonar ping.
    x = np.sin(2 * np.pi * 1320 * t_axis(1.4)) * np.exp(-t_axis(1.4) * 4)
    save("sonar", reverb(x, 1.2, 0.45), 0.5)
    # Device found: two quick notes up.
    x = np.zeros(int(0.6 * SR))
    for k, m in enumerate([84, 91]):
        p = pluck(m, 0.5, 1.2, 6)
        s = int(k * 0.09 * SR)
        x[s : s + len(p)] += p[: len(x) - s]
    save("found", reverb(x, 0.8, 0.25), 0.55)
    # Success chime: a bright arpeggio.
    x = np.zeros(int(2.2 * SR))
    for k, m in enumerate([72, 76, 79, 84]):
        b = bell(m, 2.0)
        s = int(k * 0.07 * SR)
        x[s : s + len(b)] += b[: len(x) - s]
    save("success", reverb(x, 1.4, 0.3), 0.6)
    # Monitor beeps.
    for name, f in [("beep_normal", 880), ("beep_warn", 1046.5), ("beep_crit", 1318.5)]:
        t = t_axis(0.16)
        x = np.sin(2 * np.pi * f * t) * env(len(t), 0.004, 0.11)
        save(name, x, 0.45)
    # Threshold alerts.
    x = np.zeros(int(0.9 * SR))
    for k, f in enumerate([660, 880, 660, 880]):
        t = t_axis(0.16)
        tone = np.sin(2 * np.pi * f * t) * env(len(t), 0.005, 0.05)
        s = int(k * 0.19 * SR)
        x[s : s + len(t)] += tone
    save("alert_warn", reverb(x, 0.6, 0.2), 0.55)
    x = np.zeros(int(1.4 * SR))
    for k in range(6):
        t = t_axis(0.12)
        f = 1175 if k % 2 == 0 else 1397
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sign(np.sin(2 * np.pi * f * t))) * env(len(t), 0.003, 0.03)
        s = int(k * 0.15 * SR)
        x[s : s + len(t)] += lp(tone, 4000)
    save("alert_crit", reverb(x, 0.7, 0.22), 0.6)
    # Kevin's footstep: a soft, rounded pop.
    t = t_axis(0.12)
    f = 260 * np.exp(-t * 18) + 140
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 38)
    save("step", x, 0.5)
    # Chat panel opens: a bubbly upward pop.
    t = t_axis(0.25)
    f = 300 + 900 * (t / 0.25) ** 0.6
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.005, 0.12)
    save("pop_open", reverb(x, 0.6, 0.25), 0.6)
    # Chat panel closes: the same pop going down.
    f = 1200 - 900 * (t / 0.25) ** 0.6
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.005, 0.12)
    save("pop_close", reverb(x, 0.6, 0.25), 0.5)
    # Incoming message: two soft notes.
    x = np.zeros(int(0.7 * SR))
    for k, m in enumerate([79, 86]):
        p = pluck(m, 0.6, 0.9, 5)
        s = int(k * 0.08 * SR)
        x[s : s + len(p)] += p[: len(x) - s]
    save("msg_in", reverb(x, 0.8, 0.25), 0.55)
    # Sent message: a quick swoosh with a click.
    t = t_axis(0.22)
    x = bp(noise(0.22), 1500, 6000) * np.sin(np.pi * t / 0.22) ** 2 * 0.6
    c = pluck(91, 0.2, 1.5, 20)
    x[-len(c) :] += c * 0.8
    save("msg_out", x, 0.5)
    # Keyboard typing: deterministic clicks for 1.2 s.
    x = np.zeros(int(1.3 * SR))
    tt = 0.0
    while tt < 1.15:
        t = t_axis(0.03)
        k = hp(noise(0.03), 2000) * np.exp(-t * 220) * (0.6 + 0.4 * rng.random())
        s = int(tt * SR)
        x[s : s + len(t)] += k
        tt += 0.06 + 0.07 * rng.random()
    save("typing", x, 0.4)
    # Confused: a questioning "hm?" glide.
    t = t_axis(0.5)
    f = 330 + 160 * (t / 0.5) ** 2 + 8 * np.sin(2 * np.pi * 7 * t)
    x = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)) * env(len(t), 0.03, 0.15)
    save("confused", lp(x, 2500), 0.55)
    # Scared: a trembling downward gasp.
    t = t_axis(0.8)
    f = 720 - 320 * (t / 0.8) + 25 * np.sin(2 * np.pi * 14 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.01, 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 16 * t))
    save("scared", reverb(lp(x, 3000), 0.6, 0.2), 0.55)
    # Laughing: bouncy "ha-ha-ha" blips stepping down.
    x = np.zeros(int(1.3 * SR))
    for k in range(6):
        t = t_axis(0.14)
        f0 = 620 - k * 35
        f = f0 + 120 * np.sin(np.pi * t / 0.14)
        b = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)) * np.sin(np.pi * t / 0.14) ** 1.5
        s = int(k * 0.17 * SR)
        x[s : s + len(t)] += lp(b, 3000)
    save("laugh", reverb(x, 0.6, 0.2), 0.55)
    # Happy sparkle.
    x = np.zeros(int(1.4 * SR))
    for k, m in enumerate([84, 88, 91, 96]):
        b = bell(m, 1.0)
        s = int(k * 0.05 * SR)
        x[s : s + len(b)] += b[: len(x) - s]
    save("sparkle", reverb(x, 1.0, 0.3), 0.4)
    # Customization swaps, rising in pitch.
    for i, m in enumerate([72, 74, 76, 79, 81, 84]):
        t = t_axis(0.3)
        f = hz(m) * (1 + 0.5 * np.exp(-t * 30))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)
        x += hp(noise(0.3), 4000) * np.exp(-t * 60) * 0.3
        save(f"swap{i + 1}", reverb(x, 0.5, 0.2), 0.55)
    # Circle close: a reverse swell that cuts off.
    sec = 1.0
    t = t_axis(sec)
    x = lp(noise(sec), 1200) * (t / sec) ** 3 + np.sin(2 * np.pi * 55 * t) * (t / sec) ** 2 * 0.6
    save("close", x, 0.6)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(ROOT, "src", "v2", "timeline.json")) as f:
        timeline = json.load(f)
    with open(os.path.join(ROOT, "src", "v2", "audio-cues.json")) as f:
        cues = json.load(f)
    sfx()
    m = music(timeline, cues)
    save("music", m, 0.5)
    print("music seconds", len(m) / SR, "files", sorted(os.listdir(OUT)))
