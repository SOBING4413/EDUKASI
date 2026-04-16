#!/usr/bin/env python3
# Scan internal network untuk SIAK instances lain
import subprocess, socket, threading

def scan_port(ip, port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1)
    result = sock.connect_ex((ip, port))
    if result == 0:
        print(f"[+] SIAK? {ip}:{port}")
        subprocess.run(["nmap", "-sV", f"{ip}"])

def scan_network():
    base = ".".join(socket.gethostbyname(socket.gethostname()).split(".")[:-1])
    threads = []
    for i in range(1,255):
        ip = f"{base}.{i}"
        t = threading.Thread(target=scan_port, args=(ip, 80))
        t.start()
        threads.append(t)
    for t in threads: t.join()

scan_network()