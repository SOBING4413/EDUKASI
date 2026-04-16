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
  echo "[!] Hanya mode 'audit' yang diizinkan."
  exit 2
fi

if [[ ! -f config.yaml ]]; then
  echo "[!] config.yaml tidak ditemukan."
  exit 1
fi

python3 runner.py "$TARGET" --mode "$MODE"
echo "[+] Audit selesai. Tidak ada aksi eksploitasi/persistence/exfil yang dijalankan."
