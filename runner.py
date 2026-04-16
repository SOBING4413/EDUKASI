#!/usr/bin/env python3
"""Safe audit orchestrator.

This script intentionally runs in defensive audit mode only.
It performs local checks for script syntax/readability and validates
configuration, without launching offensive actions.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None

ROOT = Path(__file__).resolve().parent


def run_command(cmd: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def load_config() -> dict:
    config_path = ROOT / "config.yaml"
    if not config_path.exists():
        raise FileNotFoundError("config.yaml tidak ditemukan")
    if yaml is not None:
        with config_path.open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        if not isinstance(data, dict):
            raise ValueError("config.yaml harus berupa object/dictionary")
        return data

    # Fallback parser when PyYAML is unavailable: collect top-level sections only.
    data: dict[str, dict] = {}
    for raw in config_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not raw.startswith(" ") and line.endswith(":"):
            data[line[:-1]] = {}
    if not data:
        raise ValueError("config.yaml tidak bisa diparsing tanpa dependency yaml")
    return data


def check_shell_scripts() -> list[tuple[str, bool, str]]:
    results: list[tuple[str, bool, str]] = []
    for script in sorted(ROOT.glob("*.sh")):
        code, _, err = run_command(["bash", "-n", str(script.name)])
        ok = code == 0
        msg = "syntax ok" if ok else (err or "syntax error")
        results.append((script.name, ok, msg))
    return results


def check_python_scripts() -> list[tuple[str, bool, str]]:
    results: list[tuple[str, bool, str]] = []
    for script in sorted(ROOT.glob("*.py")):
        code, _, err = run_command([sys.executable, "-m", "py_compile", str(script.name)])
        ok = code == 0
        msg = "compile ok" if ok else (err or "compile error")
        results.append((script.name, ok, msg))
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Safe EDUKASI audit runner")
    parser.add_argument("target", help="Hostname/IP target untuk validasi format")
    parser.add_argument("--mode", default="audit", choices=["audit"])
    args = parser.parse_args()

    if not args.target.strip():
        print("[!] Target tidak boleh kosong")
        return 2

    try:
        cfg = load_config()
        print(f"[+] Config loaded: keys={sorted(cfg.keys())}")
    except Exception as exc:  # validation boundary
        print(f"[!] Config error: {exc}")
        return 1

    shell_results = check_shell_scripts()
    py_results = check_python_scripts()

    failed = 0
    print("\n[Shell checks]")
    for name, ok, msg in shell_results:
        print(f" - {name}: {'OK' if ok else 'FAIL'} ({msg})")
        failed += 0 if ok else 1

    print("\n[Python checks]")
    for name, ok, msg in py_results:
        print(f" - {name}: {'OK' if ok else 'FAIL'} ({msg})")
        failed += 0 if ok else 1

    if failed:
        print(f"\n[!] Audit selesai: {failed} issue ditemukan")
        return 1

    print("\n[+] Audit selesai: tidak ada error sintaks/kompilasi")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
