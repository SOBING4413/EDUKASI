set -euo pipefail  # Strict mode: no unset vars, no pipe failures

TARGET="${1:?Error: Provide target domain (e.g. ./recon.sh target.com)}"
OUTPUT_DIR="recon_${TARGET//./_}_$(date +%Y%m%d_%H%M%S)"
SUBS_FILE="$OUTPUT_DIR/live_subdomains.txt"
PARAMS_FILE="$OUTPUT_DIR/parameters.txt"
APIs_FILE="$OUTPUT_DIR/api_endpoints.txt"
JS_FILE="$OUTPUT_DIR/javascript_secrets.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}[+]${NC} Recon output: $OUTPUT_DIR"

# Check tools availability
check_tools() {
    local tools=(subfinder httpx ffuf dirsearch katana gau waybackurls aquatone)
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}[-] Missing tools:${NC} ${missing[*]}"
        echo "Install: apt install -y subfinder httpx-tools ffuf dirsearch katana"
        exit 1
    fi
}

# Progress indicator
spinner() {
    local pid=$!
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

echo -e "${BLUE}[*]${NC} Starting comprehensive recon on ${GREEN}$TARGET${NC}"

# 1. SUBDOMAIN ENUMERATION (Massive)
echo -e "${BLUE}[*]${NC} Phase 1: Subdomain enumeration..."
{
    # Multiple sources
    subfinder -d "$TARGET" -silent -t 100 | \
    assetfinder --subs-only "$TARGET" | \
    amass enum -passive -d "$TARGET" -timeout 10 | \
    httpx -silent -title -status-code -tech-detect -content-length \
          -timeout 10 -threads 100 -random-agent | \
    sort -u | tee "$SUBS_FILE"
    
    echo -e "\n${GREEN}[+]${NC} Found $(wc -l < "$SUBS_FILE") live subdomains"
} &

spinner

# 2. URL ENUMERATION (Massive crawling)
echo -e "${BLUE}[*]${NC} Phase 2: URL enumeration..."
{
    cat "$SUBS_FILE" | \
    while read -r sub; do
        [ -n "$sub" ] && echo "$sub"
    done | \
    tee >(katana -silent -c 50 -rl 100 -rd 5 -rs 100 -timeout 20 -f qurl | sort -u > "$OUTPUT_DIR/all_urls.txt") | \
    xargs -P 20 -I % sh -c '
        for url in %/* %; do
            [ -n "$url" ] && curl -s -I "$url" 2>/dev/null | head -1 | grep -q "200\|301\|302" && echo "$url"
        done
    ' | \
    grep -E "\.(php|asp|jsp|js|json|xml|txt)$" >> "$OUTPUT_DIR/interesting_urls.txt"
} &

spinner

# 3. API & Directory Fuzzing
echo -e "${BLUE}[*]${NC} Phase 3: API/Directory fuzzing..."
{
    # API endpoints
    dirsearch -u "https://$TARGET" \
        -e php,asp,js,json,xml,sql,txt \
        -w /usr/share/wordlists/seclists/Discovery/Web-Content/api/raft-large-directories.txt \
        -t 100 --random-agent --exclude-sizes 0B,123,404,403 \
        --format json | jq -r '.results[] | select(.status==200 or .status==301) | .url' 2>/dev/null | \
        tee "$APIs_FILE"
    
    # Parameter fuzzing
    ffuf -u "https://$TARGET/FUZZ" \
        -w /usr/share/wordlists/seclists/Discovery/Web-Content/burp-parameter-names.txt \
        -mc 200,301,302,307,308 \
        -fw 0 -fs 0 \
        -t 200 -timeout 10 \
        -recursion -recursion-depth 2 \
        -o "$OUTPUT_DIR/ffuf.json" \
        -uF 2>/dev/null | \
        grep -v "FUZZ:" | tee -a "$PARAMS_FILE"
} &

spinner

# 4. JavaScript Analysis
echo -e "${BLUE}[*]${NC} Phase 4: JavaScript secrets..."
{
    cat "$SUBS_FILE" "$OUTPUT_DIR/all_urls.txt" 2>/dev/null | \
    grep -E "\.js$" | \
    sort -u | \
    xargs -P 20 -I % sh -c '
        curl -s "%" 2>/dev/null | grep -Ei "(api_key|secret|password|token|auth|key=)" || true
    ' | tee "$JS_FILE"
} &

spinner

# 5. Advanced Enumeration
echo -e "${BLUE}[*]${NC} Phase 5: Advanced enum..."
{
    # WayBack + Gau for historical data
    waybackurls "$TARGET" | sort -u | \
    grep -E "\.(php|asp|jsp)" | \
    httpx -silent -status-code >> "$OUTPUT_DIR/historical_attacks.txt"
    
    # Screenshot all subs
    [ "$(command -v aquatone)" ] && cat "$SUBS_FILE" | aquatone -out "$OUTPUT_DIR/screenshots"
} &

spinner

wait  # Wait for all background jobs

# 6. Generate Report
echo -e "${GREEN}[+]${NC} Generating report..."
cat > "$OUTPUT_DIR/REPORT.txt" << EOF
============================================
BIJI Recon Report: $TARGET
Generated: $(date)
============================================

LIVE SUBDOMAINS (${wc -l < "$SUBS_FILE"}):
$(head -20 "$SUBS_FILE")

API ENDPOINTS (${wc -l < "$APIs_FILE"}):
$(head -10 "$APIs_FILE")

INTERESTING PARAMETERS:
$(head -10 "$PARAMS_FILE")

JAVASCRIPT SECRETS:
$(head -10 "$JS_FILE")

ATTACK PATHS TO CHECK:
$(grep -E "(upload|admin|manager|api|file)" "$OUTPUT_DIR/all_urls.txt" | head -10)

============================================
Full output in: $OUTPUT_DIR
============================================
EOF

echo -e "${GREEN}[+]${NC} ${YELLOW}COMPLETE!${NC} Check report: $OUTPUT_DIR/REPORT.txt"
echo -e "${GREEN}[+]${NC} Quick wins: ${RED}grep -r "200\|upload\|admin" $OUTPUT_DIR/${NC}"
echo -e "${GREEN}[+]${NC} Next: ./shell.py \$(head -1 $SUBS_FILE)${NC}"