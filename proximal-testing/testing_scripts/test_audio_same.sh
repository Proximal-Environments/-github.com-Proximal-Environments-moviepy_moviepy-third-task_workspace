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

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg not found in PATH" >&2
  exit 127
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MEASURE_SCRIPT="$SCRIPT_DIR/measure_audio_similarity.py"

if [[ ! -f "$MEASURE_SCRIPT" ]]; then
  echo "Error: measure_audio_similarity.py not found at $MEASURE_SCRIPT" >&2
  exit 2
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

audio_streams() {
  ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1" | wc -l | tr -d ' '
}

count_a=$(audio_streams "$video_a")
count_b=$(audio_streams "$video_b")

if [[ "$count_a" -eq 0 && "$count_b" -eq 0 ]]; then
  echo "[audio-sim] no audio in either input - treated as similar" >&2
  exit 0
fi

if [[ "$count_a" -eq 0 || "$count_b" -eq 0 ]]; then
  echo "[audio-sim] audio stream presence mismatch (A=$count_a, B=$count_b)" >&2
  exit 1
fi

threshold=${SI_SDR_THRESHOLD:-25}

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

extract_audio() {
  local input="$1"
  local output="$2"
  ffmpeg -y -v error -i "$input" -map 0:a:0 -ac 1 -ar 48000 "$output"
}

pcm_a="$tmpdir/a.wav"
pcm_b="$tmpdir/b.wav"

extract_audio "$video_a" "$pcm_a"
extract_audio "$video_b" "$pcm_b"

if [[ -n "${AUDIO_SIM_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  MEASURE_CMD=($AUDIO_SIM_CMD)
else
  if command -v uv >/dev/null 2>&1; then
    MEASURE_CMD=(uv run)
  else
    PYTHON_BIN=${PYTHON_BIN:-python3}
    if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
      echo "Error: neither 'uv' nor python interpreter '$PYTHON_BIN' found" >&2
      exit 127
    fi
    MEASURE_CMD=("$PYTHON_BIN")
  fi
fi

sdr=$("${MEASURE_CMD[@]}" "$MEASURE_SCRIPT" "$pcm_a" "$pcm_b" | tr -d '\r') || {
  echo "Error: failed to compute SI-SDR" >&2
  exit 1
}

if [[ -z "$sdr" || "$sdr" == "nan" ]]; then
  echo "[audio-sim] SI-SDR calculation returned invalid result" >&2
  exit 1
fi

printf '[audio-sim] SI-SDR=%.6f\n' "$sdr" >&2

awk -v sdr="$sdr" -v threshold="$threshold" 'BEGIN { exit (sdr+0 >= threshold+0 ? 0 : 1) }'

if [[ $? -eq 0 ]]; then
  echo "[audio-sim] above threshold (${threshold} dB)" >&2
else
  echo "[audio-sim] below threshold (${threshold} dB)" >&2
  exit 1
fi

