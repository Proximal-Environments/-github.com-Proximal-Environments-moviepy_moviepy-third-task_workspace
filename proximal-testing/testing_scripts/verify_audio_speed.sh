#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <original_media> <comparison_media>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL="$1"
COMPARISON="$2"
LOWER_BOUND=0.8
UPPER_BOUND=1.2

if [[ ! -f "$ORIGINAL" ]]; then
  echo "Original media file not found: $ORIGINAL" >&2
  exit 1
fi

if [[ ! -f "$COMPARISON" ]]; then
  echo "Comparison media file not found: $COMPARISON" >&2
  exit 1
fi

ratio="$(uv run python "$SCRIPT_DIR/measure_audio_speed.py" "$ORIGINAL" "$COMPARISON")"
echo "time-scale ratio: $ratio"

uv run python - "$ratio" "$LOWER_BOUND" "$UPPER_BOUND" <<'PY'
import sys
ratio, lower, upper = map(float, sys.argv[1:4])
if not (lower <= ratio <= upper):
    print(
        f"ratio {ratio:.6f} outside acceptable range [{lower:.2f}, {upper:.2f}]",
        file=sys.stderr,
    )
    sys.exit(1)
PY
