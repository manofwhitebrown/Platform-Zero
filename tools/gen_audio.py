#!/usr/bin/env python3
"""Deterministic audio generator for Platform Zero (AI-C).

numpy + wave only; ffmpeg (optional) turns loops/music into OGG.
Run:  python3 tools/gen_audio.py        -> writes audio/*.wav|ogg + audio/manifest.json
Style: warm, soft, music-box / old train. Loops are circular-synthesised (seamless).
Manifest: {id: {file, bus: sfx|ambience|music|ui, volume_db, loop, variants:[...]}}
"""
import json, os, subprocess, tempfile, wave, zlib
import numpy as np

SR = 22050
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio"))
MANIFEST = {}
HAVE_FFMPEG = subprocess.call("ffmpeg -version", shell=True, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL) == 0


# ---------- primitives ----------
def R(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def tt(d):
    return np.arange(int(round(d * SR))) / SR


def nz(n, r, lo=0.0, hi=SR / 2):
    """Band-limited noise (unit std). FFT based, therefore circular = loops seamlessly."""
    spec = np.fft.rfft(r.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-9
    m = np.ones_like(f)
    if lo > 0:
        m *= 1 / (1 + (lo / f) ** 4)
    if hi < SR / 2:
        m *= 1 / (1 + (f / hi) ** 4)
    x = np.fft.irfft(spec * m, n)
    return x / (np.std(x) + 1e-9)


def ad(n, a=0.004, tau=0.1):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / tau)


def hann(n):
    return np.sin(np.pi * np.arange(n) / max(n - 1, 1)) ** 2


def fade(x, a=0.004, b=0.012):
    x = x.copy()
    na, nb = min(int(a * SR), len(x) // 2), min(int(b * SR), len(x) // 2)
    if na:
        x[:na] *= np.linspace(0, 1, na)
    if nb:
        x[-nb:] *= np.linspace(1, 0, nb)
    return x


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def tine(f, d=1.6, vel=1.0):
    """Music-box tine: inharmonic partials, fast pluck, higher notes die sooner."""
    t = tt(d)
    y = np.zeros_like(t)
    k = (440.0 / f) ** 0.3
    for ratio, amp, tau in ((1, 1, 0.9), (2.0, .30, .45), (3.99, .14, .22), (6.2, .06, .12), (8.9, .03, .06)):
        if f * ratio < SR / 2.3:
            y += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (tau * k))
    y *= np.minimum(1, t / 0.002)
    click = nz(len(t), R("tc%d" % int(f)), 2000, 6000) * np.exp(-t / 0.003) * 0.05
    return (y + click) * vel


def bell(f, d=1.4, vel=1.0):
    t = tt(d)
    y = np.zeros_like(t)
    for ratio, amp, tau in ((1, 1, 0.8), (2.4, .5, .5), (3.0, .35, .35), (5.4, .2, .2), (7.1, .1, .12)):
        if f * ratio < SR / 2.3:
            y += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / tau)
    return y * np.minimum(1, t / 0.001) * vel


def put(buf, y, start, gain=1.0):
    s = int(start * SR)
    if s < 0:
        y = y[-s:]
        s = 0
    if s >= len(buf) or len(y) == 0:
        return
    e = min(len(buf), s + len(y))
    buf[s:e] += y[:e - s] * gain


def fold(buf, total):
    """Wrap everything past `total` onto the start so a rendered phrase loops seamlessly."""
    out = buf[:total].copy()
    tail = buf[total:]
    out[:len(tail)] += tail[:total]
    return out


def verb(x, sec=0.6, wet=0.3, circ=False, seed="ir"):
    n = len(x)
    L = int(sec * SR)
    ir = R(seed + str(sec)).standard_normal(L) * np.exp(-np.arange(L) / SR / (sec / 4.5))
    ir = np.convolve(ir, np.ones(5) / 5, "same")
    ir /= np.sqrt((ir ** 2).sum())
    if circ:
        y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)
        return x * (1 - wet) + y * wet
    N = n + L
    y = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)
    xp = np.concatenate([x, np.zeros(L)])
    return xp * (1 - wet) + y * wet


def echo(x, delay=0.18, fb=0.35, reps=4):
    L = len(x) + int(delay * SR * reps)
    y = np.zeros(L)
    for i in range(reps + 1):
        put(y, x, i * delay, fb ** i)
    return y


def lp(x, hz):
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) / (1 + (f / hz) ** 4), n)


def trim(x, thr=2e-3):
    idx = np.where(np.abs(x) > thr)[0]
    return x[:idx[-1] + 1] if len(idx) else x


# ---------- output ----------
def _write_wav(path, y):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())


PEAKS = {"sfx": 0.708, "ui": 0.708, "ambience": 0.708, "music": 0.5}  # -3 dB, music about -6 dB


def save(name, y, bus="sfx", vol=0.0, loop=False, ogg=False, peak=None, files=None):
    if peak is None:
        peak = PEAKS.get(bus, 0.708)
    y = np.nan_to_num(y)
    if not loop:
        y = fade(trim(y))
    y = y / (np.max(np.abs(y)) + 1e-9) * peak
    ext = "ogg" if (ogg and HAVE_FFMPEG) else "wav"
    fn = "%s.%s" % (name, ext)
    path = os.path.join(OUT, fn)
    if ext == "wav":
        _write_wav(path, y)
    else:
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, "t.wav")
            _write_wav(tmp, y)
            subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                                   "-q:a", "3", path])
    return "res://audio/" + fn


def reg(mid, files, bus, vol, loop=False):
    MANIFEST[mid] = {"file": files[0], "bus": bus, "volume_db": vol, "loop": loop, "variants": files}


def one(mid, y, bus="sfx", vol=0.0, loop=False, ogg=False):
    reg(mid, [save(mid, y, bus, vol, loop, ogg)], bus, vol, loop)


def group(mid, ys, bus="sfx", vol=0.0):
    files = [save("%s_%d" % (mid, i + 1), y, bus, vol) for i, y in enumerate(ys)]
    reg(mid, files, bus, vol)


# ---------- train ----------
def rumble(name, fast):
    n = int(8 * SR)
    r = R(name)
    t = np.arange(n) / SR
    low = nz(n, r, 25, 110 if not fast else 140)
    mid = nz(n, r, 120, 420) * (0.25 if not fast else 0.4)
    rate = 7 if not fast else 16  # integer cycles over 8 s -> seamless
    mid *= 0.6 + 0.4 * np.sin(2 * np.pi * rate * t / 8)
    hiss = nz(n, r, 500, 1400 if not fast else 2400) * (0.04 if not fast else 0.12)
    sway = 1 + 0.12 * np.sin(2 * np.pi * 3 * t / 8)
    return (low * sway + mid + hiss) * 0.4


def clack_unit(r):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    c = nz(n, r, 500, 2600) * np.exp(-t / 0.012)
    th = np.sin(2 * np.pi * 105 * t) * np.exp(-t / 0.035) * 1.2
    return c * 0.6 + th


def clack_loop(name, rate):
    n = int(8 * SR)
    r = R(name)
    buf = np.zeros(n + SR)
    for i in range(int(8 * rate)):
        t0 = i / rate
        a = 0.8 + 0.2 * r.random()
        put(buf, clack_unit(r), t0, a)
        put(buf, clack_unit(r), t0 + 0.105, a * 0.7)
    out = fold(buf, n)
    return out + lp(rumble(name + "u", False)[:n], 90) * 0.5


def brake_squeal():
    d = 2.6
    t = tt(d)
    r = R("brake")
    f = 2300 - 650 * (t / d) ** 0.7 + 25 * np.sin(2 * np.pi * 5 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) * 0.35 + np.sin(ph * 2.01) * 0.12
    y += nz(len(t), r, 2500, 4500) * 0.12
    env = np.minimum(1, t / 0.5) * np.exp(-(t / d) ** 2 * 3.5)
    env *= 0.7 + 0.3 * np.sin(2 * np.pi * 3 * t + 1)
    y = lp(y * env, 3600)
    low = lp(nz(len(t), r, 20, 160), 120) * np.exp(-t / 1.2) * 0.4
    return y + low


def steam_hiss():
    d = 3.0
    t = tt(d)
    r = R("steam")
    env = np.minimum(1, t / 0.25) * np.exp(-t / 1.1)
    return lp(nz(len(t), r, 1800, 9000) * env, 5500) * 0.5 + nz(len(t), r, 200, 800) * env * 0.08


def whistle():
    d = 1.9
    t = tt(d)
    r = R("whistle")
    vib = 1 + 0.008 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.5)
    glide = 1 + 0.03 * np.exp(-t / 0.1)
    f1, f2 = 523.25 * vib * glide, 784.0 * vib * glide
    y = np.sin(2 * np.pi * np.cumsum(f1) / SR) + 0.8 * np.sin(2 * np.pi * np.cumsum(f2) / SR) \
        + 0.1 * np.sin(2 * np.pi * np.cumsum(f1 * 3) / SR)
    breath = nz(len(t), r, 1500, 4500) * 0.08
    env = np.minimum(1, t / 0.12) * np.where(t < 1.2, 1, np.exp(-(t - 1.2) / 0.22))
    return verb(lp((y * 0.4 + breath) * env, 3000), 0.7, 0.28)


def chuff():
    d = 2.0
    n = int(d * SR)
    buf = np.zeros(n)
    r = R("chuff")
    for i in range(5):
        m = int(0.22 * SR)
        t = np.arange(m) / SR
        c = lp(nz(m, r, 80, 900), 600) * ad(m, 0.012, 0.07)
        put(buf, c, 0.1 + i * (0.24 + 0.05 * i), 1.0 - 0.1 * i)
    return buf


def tunnel_whoosh():
    d = 2.4
    t = tt(d)
    r = R("tunnel")
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    y = nz(len(t), r, 120, 1800) * env
    y = lp(y, 900 + 900 * env.max())
    thump = np.sin(2 * np.pi * 52 * t) * np.exp(-((t - 0.5) / 0.25) ** 2) * 0.6
    return y * 0.7 + thump


def thunder():
    d = 4.6
    t = tt(d)
    r = R("thunder")
    base = lp(nz(len(t), r, 25, 220), 180)
    env = np.exp(-t / 1.6) * np.minimum(1, t / 0.35)
    for k, (a, b) in enumerate(((0.9, 0.5), (1.9, 0.35), (2.8, 0.25))):
        env += b * np.exp(-((t - a) / 0.4) ** 2)
    return base * env


# ---------- world / people ----------
def door_slide():
    d = 0.9
    t = tt(d)
    r = R("door")
    env = np.sin(np.pi * np.clip(t / 0.75, 0, 1)) ** 1.5 * (t < 0.75)
    y = nz(len(t), r, 200, 1800) * env * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t))
    thunk = np.sin(2 * np.pi * 85 * t) * ad(len(t), 0.002, 0.05) * (t >= 0.75)
    n2 = np.roll(thunk, int(0.75 * SR))
    th = np.zeros(len(t))
    m = int(0.2 * SR)
    tm = np.arange(m) / SR
    put(th, np.sin(2 * np.pi * 90 * tm) * np.exp(-tm / 0.05) + nz(m, r, 300, 1500) * np.exp(-tm / 0.015) * 0.5, 0.74)
    return lp(y, 1500) * 0.5 + th


def footstep(i):
    r = R("step%d" % i)
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (105 + i * 16) * t) * np.exp(-t / 0.035)
    tap = nz(n, r, 500 + i * 120, 2200) * np.exp(-t / 0.012) * 0.7
    creak = np.sin(2 * np.pi * (620 + i * 40) * t) * np.exp(-t / 0.02) * 0.08
    return thump + tap + creak


def paper_rustle():
    d = 0.7
    n = int(d * SR)
    r = R("paper")
    buf = np.zeros(n)
    for k in range(26):
        m = int((0.006 + r.random() * 0.02) * SR)
        c = nz(m, r, 2500, 9000) * hann(m) * (0.3 + r.random() * 0.7)
        put(buf, c, r.random() * (d - 0.05) ** 1.0, 1)
    return lp(buf * (0.5 + 0.5 * hann(n)), 6500)


def page_flip():
    d = 0.5
    t = tt(d)
    r = R("flip")
    sw = nz(len(t), r, 1200, 7000) * np.sin(np.pi * np.clip(t / 0.22, 0, 1)) ** 2 * (t < 0.22)
    flap = nz(len(t), r, 400, 2500) * ad(len(t), 0.002, 0.04) * 0.8
    out = np.zeros(len(t))
    out += sw * 0.6
    put(out, flap[:int(0.2 * SR)], 0.2)
    return lp(out, 6000)


def counter_bell():
    return verb(bell(1760, 1.6), 0.5, 0.2) + 0.0


def knock(heavy):
    d = 0.9
    n = int(d * SR)
    buf = np.zeros(n)
    r = R("knock%d" % heavy)
    for i in range(3):
        m = int(0.12 * SR)
        t = np.arange(m) / SR
        f = 150 if heavy else 210
        k = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.03) + nz(m, r, 400, 1600) * np.exp(-t / 0.01) * 0.6
        put(buf, k, 0.05 + i * (0.22 if heavy else 0.17), 1.0 if (heavy or i == 0) else 0.7)
    return buf


def cutlery(i):
    r = R("cut%d" % i)
    n = int(0.9 * SR)
    buf = np.zeros(n)
    for k in range(3 + i):
        f = 2400 + r.random() * 2600
        t = tt(0.12)
        c = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t)) * np.exp(-t / 0.025)
        put(buf, c, r.random() * 0.7, 0.4 + r.random() * 0.6)
    return buf


# ---------- bench tools ----------
def tool_magnifier():
    d = 0.7
    t = tt(d)
    r = R("mag")
    m = int(0.3 * SR)
    sl = nz(m, r, 1500, 4500) * np.sin(np.pi * np.arange(m) / m) ** 2 * 0.5
    buf = np.zeros(len(t))
    put(buf, sl, 0)
    c = tine(2637, 0.4, 0.5)
    put(buf, nz(60, r, 1000, 5000) * ad(60, 0.001, 0.004) * 1.2, 0.3)
    put(buf, c, 0.31, 0.5)
    return lp(buf, 6000)


def tool_lamp():
    d = 1.3
    t = tt(d)
    r = R("lamp")
    click = nz(int(0.03 * SR), r, 800, 3500) * ad(int(0.03 * SR), 0.001, 0.006)
    hum = (np.sin(2 * np.pi * 120 * t) + 0.5 * np.sin(2 * np.pi * 240 * t) + 0.2 * np.sin(2 * np.pi * 360 * t))
    env = np.minimum(1, t / 0.25) * np.exp(-np.maximum(t - 0.4, 0) / 0.5)
    buf = hum * env * 0.35
    put(buf, click, 0, 1.4)
    put(buf, tine(1318, 0.9, 0.35), 0.03)
    return buf


def tool_ear():
    d = 1.3
    t = tt(d)
    buf = np.zeros(len(t))
    m = int(0.25 * SR)
    tm = np.arange(m) / SR
    put(buf, np.sin(2 * np.pi * 68 * tm) * np.exp(-tm / 0.07) * 1.2, 0.0)
    for i in range(4):
        ring = np.sin(2 * np.pi * (330 - i * 20) * t[:int(0.6 * SR)]) * np.exp(-t[:int(0.6 * SR)] / 0.15)
        put(buf, ring * (1 + 0.6 * np.sin(2 * np.pi * 9 * t[:len(ring)])), 0.12 + i * 0.16, 0.35 * 0.55 ** i)
    return lp(buf, 2500)


def tool_nose():
    d = 0.9
    n = int(d * SR)
    buf = np.zeros(n)
    r = R("nose")
    for i, (a, b) in enumerate(((0.05, 0.22), (0.36, 0.28))):
        m = int(b * SR)
        s = nz(m, r, 500, 3200) * np.sin(np.pi * np.arange(m) / m) ** 1.4
        put(buf, s, a, 0.9 - 0.2 * i)
    return lp(buf, 3200) * 0.6


def tool_brush():
    d = 0.8
    t = tt(d)
    r = R("brush")
    y = nz(len(t), r, 1800, 8000) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 7 * t))) * np.sin(np.pi * t / d) ** 0.6
    return lp(y, 5500) * 0.5


# ---------- feedback / rewards ----------
def clue_found():
    buf = np.zeros(int(1.4 * SR))
    for i, m in enumerate((79, 83, 86, 91)):
        put(buf, tine(mtof(m), 1.0, 0.7), i * 0.07, 1.0)
    return verb(echo(buf, 0.16, 0.3, 3), 0.7, 0.25)


def handover_success():
    buf = np.zeros(int(2.4 * SR))
    for i, m in enumerate((72, 76, 79, 84)):
        put(buf, tine(mtof(m), 1.4, 0.8), i * 0.13)
    for m in (72, 76, 79):
        put(buf, tine(mtof(m + 12), 1.8, 0.45), 0.55)
    return verb(buf, 0.9, 0.28)


def refuse():
    buf = np.zeros(int(1.2 * SR))
    for i, m in enumerate((72, 67)):
        t = tt(0.6)
        s = np.sin(2 * np.pi * mtof(m) * t) * np.minimum(1, t / 0.04) * np.exp(-t / 0.18) + \
            0.25 * np.sin(2 * np.pi * mtof(m) * 2 * t) * np.exp(-t / 0.1)
        put(buf, s, i * 0.17, 0.7)
    return verb(lp(buf, 2200), 0.5, 0.2)


def token_clink():
    buf = np.zeros(int(0.7 * SR))
    for i, f in enumerate((3150, 4100)):
        t = tt(0.4)
        c = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t)) * np.exp(-t / 0.08)
        put(buf, c, i * 0.05, 0.7)
    return buf


def tier_up():
    buf = np.zeros(int(3.6 * SR))
    for i, m in enumerate((67, 72, 76, 79, 84, 88)):
        put(buf, tine(mtof(m), 1.6, 0.8), i * 0.16)
    for m in (60, 67, 72, 76):
        put(buf, tine(mtof(m), 2.4, 0.5), 1.1)
    return verb(echo(buf, 0.22, 0.28, 3), 1.2, 0.3)


def car_unlocked():
    buf = np.zeros(int(2.2 * SR))
    put(buf, bell(mtof(79), 1.6, 0.8), 0.0)
    put(buf, bell(mtof(86), 1.6, 0.6), 0.18)
    t = tt(0.8)
    put(buf, nz(len(t), R("unlock"), 300, 2200) * np.sin(np.pi * t / 0.8) ** 2 * 0.15, 0.0)
    return verb(buf, 0.8, 0.25)


def ui_tone(freqs, d=0.09, vol=0.6, tri=False):
    buf = np.zeros(int((d * len(freqs) + 0.12) * SR))
    for i, f in enumerate(freqs):
        t = tt(d + 0.05)
        s = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 2 * t)
        put(buf, s * ad(len(t), 0.003, 0.035), i * d * 0.9, vol)
    return lp(buf, 4000)


def toast():
    return verb(tine(mtof(88), 0.9, 0.7) + tine(mtof(91), 0.9, 0.35) * 0.0, 0.4, 0.2)


def map_open():
    out = np.zeros(int(1.1 * SR))
    put(out, paper_rustle()[:int(0.5 * SR)] * 0.5, 0.0)
    put(out, bell(mtof(79), 0.9, 0.5), 0.12)
    put(out, bell(mtof(84), 0.8, 0.3), 0.26)
    return verb(lp(out, 5000), 0.4, 0.2)


def map_close():
    out = np.zeros(int(0.9 * SR))
    put(out, bell(mtof(84), 0.6, 0.35), 0.0)
    put(out, bell(mtof(76), 0.7, 0.4), 0.1)
    put(out, page_flip()[:int(0.35 * SR)] * 0.5, 0.18)
    return verb(lp(out, 5000), 0.4, 0.2)


def map_select():
    return lp(bell(mtof(86), 0.35, 0.6) + 0.4 * bell(mtof(74), 0.35, 0.4), 6000)


def blip(mood, k):
    base = dict(calm=300, hurried=420, worried=270, shy=520, grumpy=165)[mood] * (0.85, 1.0, 1.12, 1.3)[k]
    dur = dict(calm=.09, hurried=.055, worried=.12, shy=.07, grumpy=.11)[mood]
    glide = dict(calm=.04, hurried=.12, worried=-.15, shy=.08, grumpy=-.08)[mood]
    t = tt(dur)
    f = base * (1 + glide * t / dur)
    if mood == "worried":
        f = f * (1 + 0.025 * np.sin(2 * np.pi * 28 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = {"calm": (1, .35, .12), "hurried": (1, .5, .25), "worried": (1, .3, .1),
         "shy": (1, .12, .02), "grumpy": (1, .6, .4)}[mood]
    y = w[0] * np.sin(ph) + w[1] * np.sin(2 * ph) + w[2] * np.sin(3 * ph)
    if mood == "grumpy":
        y = lp(y, 900)
    return y * hann(len(t))


# ---------- ambience loops ----------
def rain_loop():
    n = int(12 * SR)
    r = R("rain")
    t = np.arange(n) / SR
    y = nz(n, r, 900, 9500) * 0.7 + nz(n, r, 150, 700) * 0.35
    y *= 1 + 0.08 * np.sin(2 * np.pi * 3 * t / 12 + 1)
    buf = np.zeros(n + 2000)
    for _ in range(140):
        m = int(0.004 * SR)
        d = nz(m, r, 2500, 7000) * ad(m, 0.0005, 0.0012)
        put(buf, d, r.random() * 12, 0.5 + r.random())
    return y + fold(buf, n) * 0.5


def wind_loop():
    n = int(12 * SR)
    r = R("wind")
    t = np.arange(n) / SR
    y = nz(n, r, 120, 900)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * 2 * t / 12 + 0.3) * np.sin(2 * np.pi * 3 * t / 12 + 1.1)
    return lp(y * gust, 1100) * 0.9


def lamp_hum_loop():
    n = int(4 * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 120 * t) + 0.4 * np.sin(2 * np.pi * 240 * t) + 0.15 * np.sin(2 * np.pi * 360 * t)
    return y * (1 + 0.05 * np.sin(2 * np.pi * 2 * t / 4)) * 0.4 + nz(n, R("lh"), 3000, 6000) * 0.01


def dining_murmur():
    n = int(12 * SR)
    r = R("murmur")
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k in range(7):
        lo = 250 + r.random() * 350
        voice = nz(n, r, lo, lo * 3.2)
        cyc = int(34 + r.integers(0, 28))
        syl = np.maximum(0, np.sin(2 * np.pi * cyc * t / 12 + r.random() * 6)) ** 1.3
        phr = 0.5 + 0.5 * np.sin(2 * np.pi * int(1 + r.integers(0, 3)) * t / 12 + r.random() * 6)
        y += voice * syl * phr * (0.5 + 0.5 * r.random())
    buf = np.zeros(n + SR)
    for _ in range(14):
        f = 2600 + r.random() * 2200
        tm = tt(0.09)
        put(buf, np.sin(2 * np.pi * f * tm) * np.exp(-tm / 0.02), r.random() * 12, 0.25 + r.random() * 0.5)
    return lp(y, 2200) * 0.4 + fold(buf, n) * 0.08


# ---------- music ----------
def pad(freqs, d, vol=0.2):
    t = tt(d)
    y = np.zeros_like(t)
    for f in freqs:
        for det in (0.997, 1.003):
            y += np.sin(2 * np.pi * f * det * t)
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    return y * env * vol / max(1, len(freqs)) * (1 + 0.1 * np.sin(2 * np.pi * 0.3 * t))


def compose(name, bpm, bars, chords, melody_notes, mel_density, mel_vel, wet, arp=False, bass=True, seed=1):
    beat = 60.0 / bpm
    total = int(round(bars * 4 * beat * SR))
    buf = np.zeros(total + 6 * SR)
    r = R(name)
    for b in range(bars):
        ch = chords[b % len(chords)]
        t0 = b * 4 * beat
        put(buf, pad([mtof(m) for m in ch], 4 * beat * 1.35, 0.5), t0 - 0.2, 1.0)
        if bass:
            put(buf, tine(mtof(ch[0] - 12), 2.6, 0.55), t0)
            put(buf, tine(mtof(ch[0] - 12), 2.0, 0.35), t0 + 2 * beat)
        if arp:
            for q in range(8):
                put(buf, tine(mtof(ch[q % len(ch)] + 12), 1.4, 0.18), t0 + q * beat * 0.5)
    # 4-bar motif reused (with small variation) so it feels composed
    phrases = []
    for p in range(3):
        pr = R("%s_phrase%d" % (name, p % 2))
        idx = int(len(melody_notes) / 2)
        notes = []
        for step in range(4 * 8):
            if pr.random() < mel_density:
                idx = int(np.clip(idx + pr.integers(-2, 3), 0, len(melody_notes) - 1))
                notes.append((step * beat * 0.5, melody_notes[idx]))
        phrases.append(notes)
    for b in range(0, bars, 4):
        notes = phrases[(b // 4) % 3]
        for off, m in notes:
            if b * 4 * beat + off < bars * 4 * beat:
                put(buf, tine(mtof(m), 2.0, mel_vel), b * 4 * beat + off)
    y = fold(buf, total)
    return verb(y, 2.4, wet, circ=True, seed=name)


def music_cozy():  # 90 bpm * 12 bars = 32 s
    D, Bm, G, A = (62, 66, 69, 73), (59, 62, 66, 69), (55, 59, 62, 66), (57, 61, 64, 69)
    return compose("cozy", 90, 12, [D, D, Bm, Bm, G, G, A, A, D, Bm, G, A],
                   [74, 76, 78, 81, 83, 86, 88, 90], 0.42, 0.55, 0.3)


def music_travel():  # 60 bpm * 8 bars = 32 s
    F, Dm, Bb, C = (53, 57, 60, 64), (50, 57, 60, 64), (46, 53, 57, 62), (48, 55, 60, 64)
    return compose("travel", 60, 8, [F, Dm, Bb, C, F, Dm, Bb, C],
                   [72, 74, 76, 79, 81, 84, 86], 0.28, 0.45, 0.45, arp=True)


def music_suspense():  # 75 bpm * 10 bars = 32 s
    beat = 60 / 75
    total = int(round(10 * 4 * beat * SR))
    buf = np.zeros(total + 6 * SR)
    r = R("susp")
    chords = [(57, 60, 64, 67), (53, 57, 60, 64), (50, 53, 57, 60), (52, 56, 59, 62), (57, 60, 64, 67)]
    for b in range(10):
        ch = chords[b // 2]
        t0 = b * 4 * beat
        put(buf, pad([mtof(m) for m in ch], 4 * beat * 1.3, 0.45), t0 - 0.2)
        put(buf, tine(mtof(ch[0] - 24), 3.0, 0.7), t0)
        for hb in (1.0, 1.6):  # soft heartbeat
            m = int(0.25 * SR)
            tm = np.arange(m) / SR
            put(buf, np.sin(2 * np.pi * 52 * tm) * np.exp(-tm / 0.06) * 0.5, t0 + (hb + 0.0) * beat * 2)
    hi = [69, 72, 75, 76, 77, 81, 83]
    pr = R("susp_hi")
    for q in range(10 * 4 * 2):
        if pr.random() < 0.18:
            put(buf, tine(mtof(hi[pr.integers(0, len(hi))]), 2.2, 0.35), q * beat * 0.5)
    y = fold(buf, total)
    return verb(y, 3.0, 0.4, circ=True, seed="susp")


# ---------- main ----------
def main():
    os.makedirs(OUT, exist_ok=True)
    # train
    one("train_rumble_slow", rumble("rs", False), "ambience", -8, True, True)
    one("train_rumble_fast", rumble("rf", True), "ambience", -8, True, True)
    one("rail_clack_slow", clack_loop("cs", 1.5), "ambience", -10, True, True)
    one("rail_clack_fast", clack_loop("cf", 3.0), "ambience", -10, True, True)
    one("brake_squeal", brake_squeal(), "sfx", -6)
    one("steam_hiss", steam_hiss(), "sfx", -8)
    one("whistle_depart", whistle(), "sfx", -7)
    one("chuff", chuff(), "sfx", -9)
    one("tunnel_whoosh", tunnel_whoosh(), "ambience", -8)
    one("thunder", thunder(), "ambience", -6)
    one("rain_loop", rain_loop(), "ambience", -12, True, True)
    one("wind_loop", wind_loop(), "ambience", -14, True, True)
    one("lamp_hum_loop", lamp_hum_loop(), "ambience", -22, True, True)
    one("dining_murmur", dining_murmur(), "ambience", -14, True, True)
    # world / people
    one("door_slide", door_slide(), "sfx", -8)
    group("footstep", [footstep(i) for i in range(3)], "sfx", -16)
    one("paper_rustle", paper_rustle(), "sfx", -12)
    one("page_flip", page_flip(), "sfx", -12)
    one("counter_bell", counter_bell(), "sfx", -8)
    one("knock_shy", knock(0), "sfx", -10)
    one("knock_grumpy", knock(1), "sfx", -7)
    group("cutlery", [cutlery(i) for i in range(3)], "sfx", -16)
    # bench tools
    one("tool_magnifier", tool_magnifier(), "sfx", -9)
    one("tool_lamp", tool_lamp(), "sfx", -9)
    one("tool_ear", tool_ear(), "sfx", -9)
    one("tool_nose", tool_nose(), "sfx", -11)
    one("tool_brush", tool_brush(), "sfx", -11)
    # feedback
    one("clue_found", clue_found(), "sfx", -8)
    one("handover_success", handover_success(), "sfx", -6)
    one("refuse", refuse(), "sfx", -9)
    one("token_clink", token_clink(), "sfx", -10)
    one("tier_up", tier_up(), "sfx", -5)
    one("car_unlocked", car_unlocked(), "sfx", -6)
    # ui
    one("ui_tap", ui_tone([880], 0.06, 0.5), "ui", -14)
    one("ui_open", ui_tone([660, 990], 0.07, 0.5), "ui", -13)
    one("ui_close", ui_tone([990, 660], 0.07, 0.5), "ui", -13)
    one("ui_back", ui_tone([520], 0.08, 0.5), "ui", -14)
    one("ui_toggle", ui_tone([740, 880], 0.045, 0.5), "ui", -14)
    one("toast", toast(), "ui", -12)
    one("map_open", map_open(), "ui", -12)
    one("map_close", map_close(), "ui", -13)
    one("map_select", map_select(), "ui", -14)
    # voices
    for mood in ("calm", "hurried", "worried", "shy", "grumpy"):
        group("blip_" + mood, [blip(mood, k) for k in range(4)], "sfx", -14)
    # music
    one("music_cozy", music_cozy(), "music", -14, True, True)
    one("music_travel", music_travel(), "music", -14, True, True)
    one("music_suspense", music_suspense(), "music", -16, True, True)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(MANIFEST, f, indent=1, sort_keys=True)
        f.write("\n")
    total = sum(os.path.getsize(os.path.join(OUT, x)) for x in os.listdir(OUT) if x.endswith((".wav", ".ogg")))
    print("%d ids, audio/ = %.2f MB" % (len(MANIFEST), total / 1e6))


if __name__ == "__main__":
    main()
