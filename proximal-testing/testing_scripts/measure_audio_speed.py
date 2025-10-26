from argparse import ArgumentParser
from pathlib import Path

import librosa


def compute_time_scale_ratio(original: Path, comparison: Path, n_mfcc: int) -> float:
    orig, sr = librosa.load(original, mono=True)
    slow, _ = librosa.load(comparison, mono=True, sr=sr)

    orig_mfcc = librosa.feature.mfcc(y=orig, sr=sr, n_mfcc=n_mfcc)
    slow_mfcc = librosa.feature.mfcc(y=slow, sr=sr, n_mfcc=n_mfcc)

    # subseq=True handles trimming; best_path aligns slow inside orig
    _, wp = librosa.sequence.dtw(orig_mfcc, slow_mfcc, subseq=True)

    start, end = wp[0], wp[-1]
    orig_len = abs(end[0] - start[0]) + 1
    slow_len = abs(end[1] - start[1]) + 1
    return orig_len / slow_len


def main() -> None:
    parser = ArgumentParser(description="Estimate relative time-scale between two media files.")
    parser.add_argument("original", type=Path, help="Path to the reference/original media file")
    parser.add_argument("comparison", type=Path, help="Path to the comparison media file")
    parser.add_argument(
        "--n-mfcc",
        type=int,
        default=20,
        help="Number of MFCCs to compute during DTW alignment (default: 20)",
    )

    args = parser.parse_args()
    ratio = compute_time_scale_ratio(args.original, args.comparison, args.n_mfcc)
    print(f"{ratio:.6f}")


if __name__ == "__main__":
    main()