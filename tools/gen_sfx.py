#!/usr/bin/env python3
"""Synthesize a cohesive royalty-free UI/feedback SFX set for Puzzle Hub.
Mono, 44.1kHz. Outputs WAV; ffmpeg converts to OGG afterwards.
Design: soft additive bells on a C-major pentatonic, fast attacks, exp decays,
gentle pitch glides. Nothing harsh — these get heard constantly."""
import numpy as np, os, struct, wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "sfx")
os.makedirs(OUT, exist_ok=True)

def t(dur): return np.linspace(0, dur, int(SR*dur), endpoint=False)

def adsr(n, a=0.005, d=0.04, s=0.0, r=0.06, sl=0.6):
    """Simple AD(S)R as a per-sample envelope of length n (seconds-based segs)."""
    a_n=int(SR*a); d_n=int(SR*d); r_n=int(SR*r)
    s_n=max(0, n-a_n-d_n-r_n)
    env=np.zeros(n)
    i=0
    if a_n: env[i:i+a_n]=np.linspace(0,1,a_n); i+=a_n
    if d_n: env[i:i+d_n]=np.linspace(1,sl,d_n); i+=d_n
    if s_n: env[i:i+s_n]=sl; i+=s_n
    if r_n: env[i:i+r_n]=np.linspace(sl,0,r_n); i+=r_n
    if i<n: env[i:]=0
    return env

def expdec(dur, tau):
    x=t(dur); return np.exp(-x/tau)

def tone(freq, dur, env=None, wave_kind="sine", detune=0.0, gliss=None):
    x=t(dur)
    f=np.full_like(x, freq, dtype=float)
    if gliss is not None:  # gliss = end freq -> linear glide
        f=np.linspace(freq, gliss, len(x))
    phase=2*np.pi*np.cumsum(f)/SR
    if wave_kind=="sine": w=np.sin(phase)
    elif wave_kind=="tri": w=2/np.pi*np.arcsin(np.sin(phase))
    elif wave_kind=="square": w=np.sign(np.sin(phase))
    else: w=np.sin(phase)
    if detune:
        phase2=2*np.pi*np.cumsum(f*(1+detune))/SR
        w=0.6*w+0.4*np.sin(phase2)
    if env is not None:
        w=w*env
    return w

def bell(freq, dur, tau, partials=((1,1.0),(2,0.4),(3,0.18)), gliss=None):
    out=np.zeros(int(SR*dur))
    for mult,amp in partials:
        g = None if gliss is None else gliss*mult
        out += amp*tone(freq*mult, dur, expdec(dur,tau), "sine", gliss=g)
    return out

def mix(base, seg, off_s=0.0):
    """Add seg into base at offset off_s seconds, growing base if needed."""
    off=int(SR*off_s); end=off+len(seg)
    if end>len(base):
        base=np.concatenate([base, np.zeros(end-len(base))])
    base[off:end]+=seg
    return base

def noise(dur): return np.random.uniform(-1,1,int(SR*dur))

def lowpass(x, alpha=0.2):
    y=np.zeros_like(x); acc=0.0
    for i in range(len(x)):
        acc += alpha*(x[i]-acc); y[i]=acc
    return y

def norm(x, peak=0.85):
    m=np.max(np.abs(x)) or 1.0
    return x/m*peak

def soft_clip(x): return np.tanh(x*1.1)

def save_wav(name, x):
    x=norm(soft_clip(x))
    # short fade out tail to kill clicks
    fn=min(len(x), int(SR*0.01))
    if fn>0: x[-fn:]*=np.linspace(1,0,fn)
    pcm=(x*32767).astype(np.int16)
    p=os.path.join(OUT, name+".wav")
    with wave.open(p,"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name:14s} {len(x)/SR*1000:6.0f} ms")

# Pentatonic-ish reference freqs (C major)
C5,D5,E5,G5,A5,C6,D6,E6,G6,A6,C7 = 523.25,587.33,659.25,783.99,880.0,1046.5,1174.66,1318.5,1568.0,1760.0,2093.0

# 1. tap — soft short "tok" + tiny click
def s_tap():
    d=0.055
    body=tone(A5, d, expdec(d,0.015), "sine")
    click=noise(0.004)*np.exp(-t(0.004)/0.0015)
    x=np.zeros(int(SR*d)); x[:len(click)]+=click*0.5; x+=body*0.9
    return x

# 2. key — softer, lower than tap (keyboard press)
def s_key():
    d=0.05
    body=tone(E5, d, expdec(d,0.018), "tri")
    click=noise(0.003)*np.exp(-t(0.003)/0.0012)
    x=np.zeros(int(SR*d)); x[:len(click)]+=click*0.35; x+=body*0.85
    return x

# 3. button — pleasant two-note up confirm
def s_button():
    x=np.zeros(int(SR*0.16))
    x=mix(x, bell(E5,0.07,0.05)*0.7, 0.0)
    x=mix(x, bell(A5,0.13,0.06)*0.9, 0.045)
    return x

# 4. transition — airy whoosh (band noise swell + faint glide)
def s_transition():
    d=0.30
    nz=lowpass(noise(d), 0.12)
    nz=lowpass(nz,0.25)
    swell=np.sin(np.linspace(0,np.pi,int(SR*d)))**1.6
    glide=tone(G5,d,expdec(d,0.2),"sine",gliss=C6)*0.15
    x=nz*swell*0.9+glide*swell
    return x

# 5. correct — bright rising two-tone bell
def s_correct():
    x=np.zeros(int(SR*0.24))
    x=mix(x, bell(G5,0.10,0.06)*0.7, 0.0)
    x=mix(x, bell(C6,0.20,0.10)*0.95, 0.055)
    return x

# 6. error — soft descending two-tone, light buzz (not harsh)
def s_error():
    x=np.zeros(int(SR*0.26))
    x=mix(x, tone(A5,0.12,expdec(0.12,0.06),"tri")*0.6, 0.0)
    x=mix(x, tone(E5,0.20,expdec(0.20,0.09),"tri",detune=0.004)*0.8, 0.07)
    x=mix(x, tone(E5*0.5,0.18,expdec(0.18,0.08),"sine")*0.25, 0.07)
    return x

# 7. coin — classic bright two-note ding
def s_coin():
    x=np.zeros(int(SR*0.24))
    x=mix(x, bell(E6,0.06,0.04,partials=((1,1.0),(2,0.5),(3,0.25)))*0.7, 0.0)
    x=mix(x, bell(G6,0.20,0.10,partials=((1,1.0),(2,0.55),(3,0.3),(4,0.15)))*0.95, 0.04)
    return x

# 8. star — sparkle: quick ascending high arpeggio + shimmer tail
def s_star():
    notes=[C6,E6,G6,C7]; d=0.34
    x=np.zeros(int(SR*d))
    for i,f in enumerate(notes):
        b=bell(f,0.26,0.11,partials=((1,1.0),(2,0.5),(3,0.28),(5,0.12)))*(0.5+0.12*i)
        x=mix(x, b, 0.035*i)
    x*=1+0.18*np.sin(2*np.pi*22*t(len(x)/SR))
    return x

# 9. win — celebratory rising arpeggio chord
def s_win():
    notes=[C5,E5,G5,C6,E6]; d=0.62
    x=np.zeros(int(SR*d))
    for i,f in enumerate(notes):
        b=bell(f,d-0.06*i,0.18,partials=((1,1.0),(2,0.5),(3,0.25),(4,0.12)))*0.6
        x=mix(x, b, 0.06*i)
    x*=1+0.10*np.sin(2*np.pi*6*t(len(x)/SR))
    return x

# 10. levelup — bigger triumphant fanfare (arp -> held chord shimmer)
def s_levelup():
    d=0.95
    x=np.zeros(int(SR*d))
    for i,f in enumerate([C5,E5,G5,C6]):
        b=bell(f,0.5,0.14,partials=((1,1.0),(2,0.55),(3,0.3)))*0.5
        x=mix(x, b, 0.07*i)
    for f in [C6,E6,G6]:
        c=bell(f,d-0.30,0.32,partials=((1,1.0),(2,0.5),(3,0.28),(5,0.12)))*0.45
        x=mix(x, c, 0.30)
    x*=1+0.14*np.sin(2*np.pi*7*t(len(x)/SR))
    return x

# 11. hint — gentle magical shimmer up
def s_hint():
    d=0.40
    x=tone(G5,d,expdec(d,0.22),"sine",gliss=E6)*0.5
    for i,f in enumerate([C6,E6,G6]):
        b=bell(f,0.3,0.12,partials=((1,1.0),(2,0.45),(4,0.18)))*0.4
        x=mix(x, b, 0.05*i)
    x*=1+0.2*np.sin(2*np.pi*18*t(len(x)/SR))
    return x

builders={
 "snd_tap":s_tap,"snd_key":s_key,"snd_button":s_button,"snd_transition":s_transition,
 "snd_correct":s_correct,"snd_error":s_error,"snd_coin":s_coin,"snd_star":s_star,
 "snd_win":s_win,"snd_levelup":s_levelup,"snd_hint":s_hint,
}
np.random.seed(7)
for name,fn in builders.items():
    save_wav(name, fn().astype(float))
print("done ->", OUT)
