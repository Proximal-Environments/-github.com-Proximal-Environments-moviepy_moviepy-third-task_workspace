#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <video>" >&2
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

video="$1"

if [[ ! -f "$video" ]]; then
  echo "Error: file not found: $video" >&2
  exit 2
fi

audio_streams() {
  ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1" | wc -l | tr -d ' '
}

stream_count=$(audio_streams "$video")

if [[ "$stream_count" -eq 0 ]]; then
  echo "[audio-silence] no audio streams present" >&2
  exit 1
fi

stream_index=${AUDIO_STREAM_INDEX:-0}

if [[ "$stream_index" -lt 0 ]]; then
  echo "Error: AUDIO_STREAM_INDEX must be non-negative" >&2
  exit 2
fi

if (( stream_index >= stream_count )); then
  echo "Error: audio stream index $stream_index out of range (max $(($stream_count - 1)))" >&2
  exit 2
fi

threshold=${SILENT_MAX_VOLUME_DB:--60}

analysis_log=$(ffmpeg -hide_banner -nostats -loglevel info -i "$video" -map 0:a:"$stream_index" -filter:a volumedetect -f null - 2>&1 || true)

max_volume_line=$(printf '%s\n' "$analysis_log" | grep -E "max_volume: " | tail -n 1 || true)

if [[ -z "$max_volume_line" ]]; then
  printf '%s\n' "$analysis_log" >&2
  echo "Error: unable to determine max volume" >&2
  exit 1
fi

max_volume_value=$(printf '%s\n' "$max_volume_line" | sed -E 's/.*max_volume: ([^ ]+) dB.*/\1/')

if [[ -z "$max_volume_value" ]]; then
  echo "Error: failed to parse max volume value" >&2
  exit 1
fi

if [[ "$max_volume_value" == "-inf" ]]; then
  echo "[audio-silence] audio stream present, max volume=-inf dB" >&2
  exit 0
fi

is_silent=$(awk -v max="$max_volume_value" -v threshold="$threshold" 'BEGIN {
  if (max+0 <= threshold+0) {
    print 1
  } else {
    print 0
  }
}')

if [[ "$is_silent" == "1" ]]; then
  echo "[audio-silence] audio stream present, max volume=${max_volume_value} dB (threshold=${threshold} dB)" >&2
  exit 0
else
  echo "[audio-silence] audio stream present but not silent (max volume=${max_volume_value} dB, threshold=${threshold} dB)" >&2
  exit 1
fi

