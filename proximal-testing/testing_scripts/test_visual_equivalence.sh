#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <video_a> <video_b>" >&2
  exit 2
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg not found in PATH" >&2
  exit 127
fi

if command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  HASH_CMD=(shasum -a 256)
else
  echo "Error: neither sha256sum nor shasum is available" >&2
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

compute_hash() {
  local video="$1"
  local hash

  if ! hash=$(ffmpeg -v error -i "$video" -map 0:v:0 -f framemd5 - \
    | "${HASH_CMD[@]}" \
    | awk '{print $1}'
  ); then
    echo "Error: failed to hash video: $video" >&2
    return 1
  fi

  printf '%s\n' "$hash"
}

hash_a=$(compute_hash "$video_a")
hash_b=$(compute_hash "$video_b")

if [[ "$hash_a" == "$hash_b" ]]; then
  echo "Video hashes match" >&2
  printf '%s\n' "$hash_a"
  exit 0
else
  echo "Video hashes differ" >&2
  echo "A: $hash_a" >&2
  echo "B: $hash_b" >&2
  exit 1
fi

