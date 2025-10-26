#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <reference_video> <test_video> <threshold(0..1)>" >&2
}

if [[ $# -ne 3 ]]; then
  usage
  exit 2
fi

ref_video="$1"
test_video="$2"
threshold="$3"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is not installed or not in PATH." >&2
  exit 127
fi

if [[ ! -f "$ref_video" ]]; then
  echo "Error: reference video not found: $ref_video" >&2
  exit 2
fi

if [[ ! -f "$test_video" ]]; then
  echo "Error: test video not found: $test_video" >&2
  exit 2
fi

# Validate threshold is numeric in [0,1]
if ! awk -v t="$threshold" 'BEGIN { exit ! (t ~ /^[0-9]*\.?[0-9]+$/ && t >= 0 && t <= 1) }'; then
  echo "Error: threshold must be a number between 0 and 1 (got: $threshold)" >&2
  exit 2
fi

# Compute SSIM. Use scale2ref to match sizes and -shortest to stop at the shorter stream.
# Capture stderr where FFmpeg prints SSIM stats.
ff_out="$(ffmpeg -hide_banner -nostdin \
  -i "$ref_video" -i "$test_video" \
  -filter_complex "[1:v][0:v]scale2ref=flags=bicubic[dist][ref];[dist][ref]ssim" \
  -an -f null - -shortest 2>&1 || true)"

# Extract the final All: value
ssim_val="$(printf "%s\n" "$ff_out" | grep -oE 'All:[0-9]+(\.[0-9]+)?' | tail -1 | cut -d: -f2)"

if [[ -z "${ssim_val:-}" ]]; then
  echo "Error: Failed to parse SSIM from ffmpeg output." >&2
  printf "%s\n" "$ff_out" >&2
  exit 1
fi

pass="$(awk -v s="$ssim_val" -v t="$threshold" 'BEGIN { print (s >= t) ? 1 : 0 }')"

echo "SSIM(All)=$ssim_val Threshold=$threshold -> $( [[ "$pass" == "1" ]] && echo PASS || echo FAIL )"

if [[ "$pass" == "1" ]]; then
  exit 0
else
  exit 1
fi


