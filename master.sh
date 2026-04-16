#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-}
MODE=${2:-audit}

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target> [mode]"
  echo "mode: audit (default)"
  exit 2
fi

if [[ "$MODE" != "audit" ]]; then
  echo "[!] Mode '$MODE' tidak didukung. Gunakan mode 'audit'."
  exit 2
fi

chmod +x ./*.sh
python3 runner.py "$TARGET" --mode "$MODE"
echo "[+] Audit pipeline selesai untuk target: $TARGET"
