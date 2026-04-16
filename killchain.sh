#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-}

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target>"
  exit 2
fi

echo "[i] killchain.sh dialihkan ke mode audit aman."
python3 runner.py "$TARGET" --mode audit
