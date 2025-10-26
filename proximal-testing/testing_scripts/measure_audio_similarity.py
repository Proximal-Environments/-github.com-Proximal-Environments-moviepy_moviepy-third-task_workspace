#!/usr/bin/env python3
import sys
import numpy as np
import librosa
from scipy.signal import correlate

def time_stretch_to_match(y_src, y_ref, sr, ratio=None):
    if ratio is None:
        ratio = len(y_src) / len(y_ref)
    return librosa.effects.time_stretch(y_src, rate=1.0/ratio), ratio

def best_lag(x, y, max_lag_s=1.0, sr=48000):
    max_lag = int(max_lag_s * sr)
    n = min(len(x), len(y))
    x, y = x[:n], y[:n]
    c = correlate(y, x, mode="full")
    mid = len(c)//2
    lo, hi = mid - max_lag, mid + max_lag + 1
    lag_rel = np.argmax(c[lo:hi]) + lo - mid
    return lag_rel

def align_by_lag(x, y, lag):
    if lag > 0:
        y2, x2 = y[lag:], x[:len(y)-lag]
    elif lag < 0:
        lag = -lag
        x2, y2 = x[lag:], y[:len(x)-lag]
    else:
        n = min(len(x), len(y))
        x2, y2 = x[:n], y[:n]
    n = min(len(x2), len(y2))
    return x2[:n], y2[:n]

def si_sdr(reference, estimate, eps=1e-8):
    ref, est = reference, estimate
    alpha = np.dot(est, ref) / (np.dot(ref, ref) + eps)
    s_target = alpha * ref
    e_noise = est - s_target
    return 10 * np.log10((np.sum(s_target**2) + eps) / (np.sum(e_noise**2) + eps))

def main():
    if len(sys.argv) != 3:
        print("Usage: compare.py file1.wav file2.wav", file=sys.stderr)
        sys.exit(1)

    sr = 48000
    a, _ = librosa.load(sys.argv[1], sr=sr, mono=True)
    b, _ = librosa.load(sys.argv[2], sr=sr, mono=True)

    b_unstretched, _ = time_stretch_to_match(b, a, sr)
    lag = best_lag(a, b_unstretched, sr=sr)
    a_al, b_al = align_by_lag(a, b_unstretched, lag)

    print(f"{si_sdr(a_al, b_al):.6f}")

if __name__ == "__main__":
    main()
