#!/usr/bin/env python3
"""生成牧场物语游戏的 BGM 与音效 WAV 文件（纯过程化合成，无外部依赖）。"""

import math
import struct
import wave
import os

SR = 22050  # 采样率


def write_wav(path, samples):
    """将 float[-1,1] 列表写入 16-bit PCM WAV。"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack('<h', int(v * 32767))
        w.writeframes(bytes(frames))


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def envelope(t, dur, attack=0.01, release=0.1):
    """ADSR 简化包络。"""
    if t < 0 or t > dur:
        return 0.0
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def tone(freq, dur, vol=0.3, attack=0.01, release=0.08):
    """生成一个带包络的正弦音。"""
    n = int(SR * dur)
    return [vol * envelope(i / SR, dur, attack, release) * sine(freq, i / SR)
            for i in range(n)]


def mix(*tracks):
    """混合多轨道（等长补零）。"""
    length = max(len(t) for t in tracks)
    result = [0.0] * length
    for t in tracks:
        for i, s in enumerate(t):
            result[i] += s
    return result


def concat(*tracks):
    """顺序拼接轨道。"""
    result = []
    for t in tracks:
        result.extend(t)
    return result


def silence(dur):
    return [0.0] * int(SR * dur)


# ============================================================ BGM
def gen_bgm():
    """生成 ~40 秒舒缓牧场 BGM：五声音阶旋律 + 简易和弦垫底。"""
    # C 大调五声音阶频率
    C4, D4, E4, G4, A4 = 261.63, 293.66, 329.63, 392.00, 440.00
    C5, D5, E5, G5, A5 = 523.25, 587.33, 659.25, 783.99, 880.00
    C3, G3, A3, F3 = 130.81, 196.00, 220.00, 174.61

    # 旋律音符 (频率, 时长秒)
    melody = [
        (G4, 0.4), (A4, 0.4), (C5, 0.6), (A4, 0.2), (G4, 0.4), (E4, 0.4),
        (G4, 0.6), (D4, 0.2), (E4, 0.4), (G4, 0.4), (A4, 0.8),
        (A4, 0.4), (G4, 0.4), (E4, 0.6), (D4, 0.2), (C4, 0.4), (D4, 0.4),
        (E4, 0.6), (G4, 0.2), (E4, 0.4), (D4, 0.4), (C4, 0.8),
        (C5, 0.4), (A4, 0.4), (G4, 0.6), (E4, 0.2), (G4, 0.4), (A4, 0.4),
        (C5, 0.6), (D5, 0.2), (C5, 0.4), (A4, 0.4), (G4, 0.8),
        (E4, 0.4), (G4, 0.4), (A4, 0.6), (G4, 0.2), (E4, 0.4), (D4, 0.4),
        (C4, 0.6), (D4, 0.2), (E4, 0.4), (G4, 0.4), (C4, 1.0),
    ]

    # 和弦进行（每 2.4 秒一个和弦）
    chords = [(C3, E4, G4), (G3, D4, G4), (A3, E4, A4), (F3, A4, C5),
              (C3, E4, G4), (G3, D4, G4), (A3, E4, A4), (C3, E4, G4)]

    melody_track = []
    for freq, dur in melody:
        melody_track.extend(tone(freq, dur, vol=0.18, attack=0.02, release=0.12))

    # 和弦垫底
    chord_track = []
    for root, _, _ in chords:
        chord_track.extend(tone(root, 2.4, vol=0.06, attack=0.3, release=0.4))
        chord_track_back = tone(root * 1.5, 2.4, vol=0.04, attack=0.3, release=0.4)
        # 叠加五度
        idx = len(chord_track) - int(SR * 2.4)
        for i, s in enumerate(chord_track_back):
            if idx + i < len(chord_track):
                chord_track[idx + i] += s

    # 拼接两遍旋律使总长约 40 秒
    full = mix(melody_track * 2, chord_track * 2)
    # 轻微淡入淡出
    fade = int(SR * 1.0)
    for i in range(fade):
        full[i] *= i / fade
        full[-i - 1] *= i / fade
    return full


# ============================================================ SFX
def gen_harvest():
    """收获：欢快上行琶音。"""
    return concat(
        tone(523.25, 0.08, 0.25),
        tone(659.25, 0.08, 0.25),
        tone(783.99, 0.12, 0.25),
    )


def gen_plant():
    """播种：柔和土声 + 轻音。"""
    n = int(SR * 0.25)
    thud = [0.3 * math.exp(-i / SR * 12) * sine(80, i / SR) for i in range(n)]
    chime = tone(440, 0.15, 0.12)
    return mix(thud, concat(silence(0.05), chime))


def gen_hoe():
    """锄地：沙土摩擦声。"""
    n = int(SR * 0.18)
    noise = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 18) * (1 - t / 0.18)
        noise.append(0.25 * env * (math.sin(2 * math.pi * 120 * t)
                     + 0.5 * math.sin(2 * math.pi * 200 * t)))
    return noise


def gen_coin():
    """金币：清脆叮声。"""
    return mix(
        tone(1318.51, 0.12, 0.2, release=0.1),
        concat(silence(0.04), tone(1760.0, 0.1, 0.15, release=0.08)),
    )


def gen_levelup():
    """升级：上行琶音 + 闪光。"""
    return concat(
        tone(523.25, 0.1, 0.22),
        tone(659.25, 0.1, 0.22),
        tone(783.99, 0.1, 0.22),
        tone(1046.5, 0.25, 0.25, release=0.2),
    )


def gen_water():
    """浇水：水花声。"""
    n = int(SR * 0.35)
    s = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 8)
        s.append(0.2 * env * (math.sin(2 * math.pi * 600 * t * (1 - t))
                 + 0.4 * math.sin(2 * math.pi * 300 * t)))
    return s


def gen_fish():
    """钓鱼：水花 + 卷线。"""
    splash = gen_water()
    reel = []
    for i in range(int(SR * 0.3)):
        t = i / SR
        reel.append(0.12 * math.exp(-t * 5) * sine(400 + 800 * t, t))
    return concat(splash, reel)


def gen_ui_click():
    """UI 点击：短促按键。"""
    return tone(880, 0.05, 0.15, release=0.03)


def gen_sleep():
    """睡觉：下行柔和音。"""
    return concat(
        tone(659.25, 0.15, 0.18, release=0.1),
        tone(523.25, 0.15, 0.18, release=0.1),
        tone(392.00, 0.3, 0.18, release=0.2),
    )


def main():
    base = 'assets/audio'
    files = {
        f'{base}/bgm_farm.wav': gen_bgm(),
        f'{base}/sfx_harvest.wav': gen_harvest(),
        f'{base}/sfx_plant.wav': gen_plant(),
        f'{base}/sfx_hoe.wav': gen_hoe(),
        f'{base}/sfx_coin.wav': gen_coin(),
        f'{base}/sfx_levelup.wav': gen_levelup(),
        f'{base}/sfx_water.wav': gen_water(),
        f'{base}/sfx_fish.wav': gen_fish(),
        f'{base}/sfx_click.wav': gen_ui_click(),
        f'{base}/sfx_sleep.wav': gen_sleep(),
    }
    for path, samples in files.items():
        write_wav(path, samples)
        dur = len(samples) / SR
        print(f'  {path}  {dur:.2f}s')
    print(f'生成 {len(files)} 个音频文件')


if __name__ == '__main__':
    main()
