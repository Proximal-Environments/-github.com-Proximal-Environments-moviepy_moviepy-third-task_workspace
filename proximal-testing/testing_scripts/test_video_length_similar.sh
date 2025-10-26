#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <video_a> <video_b>" >&2
  exit 2
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "Error: ffprobe not found in PATH" >&2
  exit 127
fi

video_a="$1"
video_b="$2"

if [[ ! -f "$video_a" ]]; then
  echo "Error: file not found: $video_a" >&2
  exit 2
fi

if [[ ! -f "$video_b" ]]; then
  echo "Error: file not found: $video_b" >&2
  exit 2
fi

tolerance=${DURATION_TOLERANCE_SECONDS:-0.15}

get_duration() {
  local input="$1"
  local duration
  duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input") || return 1
  if [[ -z "$duration" || "$duration" == "N/A" ]]; then
    echo "Error: could not determine duration for $input" >&2
    return 1
  fi
  printf '%s\n' "$duration"
}

dur_a=$(get_duration "$video_a") || exit 1
dur_b=$(get_duration "$video_b") || exit 1

diff=$(awk -v a="$dur_a" -v b="$dur_b" 'BEGIN {d = a - b; if (d < 0) d = -d; printf "%.6f", d}')

awk -v diff="$diff" -v tol="$tolerance" 'BEGIN { exit (diff <= tol ? 0 : 1) }'

if [[ $? -eq 0 ]]; then
  echo "[duration-check] within tolerance (diff=${diff}s, tol=${tolerance}s)" >&2
  exit 0
else
  echo "[duration-check] outside tolerance (diff=${diff}s, tol=${tolerance}s)" >&2
  exit 1
fi

