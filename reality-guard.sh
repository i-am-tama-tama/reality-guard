# ==========================================
# REALITY GUARD
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

IPSET_NAME="reality_whitelist"
CHAIN_NAME="REALITY_GUARD"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root.${NC}" 
   exit 1
fi

echo -e "${GREEN} REALITY GUARD ${NC}"


# ВВод стран
echo -e "${YELLOW}[?] Enter allowed countries (ISO codes, space separated).${NC}"
echo -e "    Example: US DE CN"
echo -n "    Selection [default: RU KZ]: "
read input_countries

if [[ -z "$input_countries" ]]; then
    ALLOWED_COUNTRIES=("RU")
else
    ALLOWED_COUNTRIES=(${=input_countries})
fi


echo -e "\n${YELLOW}[?] Enter ports to protect (space separated).${NC}"
echo -n "    Selection [default: 443]: "
read input_ports

if [[ -z "$input_ports" ]]; then
    TARGET_PORTS=(443)
else
    TARGET_PORTS=(${=input_ports})
fi


echo -e "\n${YELLOW}[?] Select protocols (tcp/udp/both).${NC}"
echo -n "    Selection [default: both]: "
read input_proto

PROTOCOLS=()
if [[ "$input_proto" == "tcp" ]]; then
    PROTOCOLS=("tcp")
elif [[ "$input_proto" == "udp" ]]; then
    PROTOCOLS=("udp")
else
    PROTOCOLS=("tcp" "udp")
fi

echo -e "\n${GREEN}[*] Configuration loaded:${NC}"
echo "    Countries: ${ALLOWED_COUNTRIES[*]}"
echo "    Ports:     ${TARGET_PORTS[*]}"
echo "    Protocols: ${PROTOCOLS[*]}"
echo "----------------------------------------"

# Проверка зависимостей
if ! command -v ipset &> /dev/null; then
    echo -e "${YELLOW}[*] Installing dependencies (ipset, curl)...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y ipset curl
    elif command -v yum &> /dev/null; then
        yum install -y ipset curl
    fi
fi


echo -e "${YELLOW}[*] Configuring IP sets (ipset)...${NC}"

ipset create $IPSET_NAME hash:net -exist

ipset flush $IPSET_NAME

for country in "${ALLOWED_COUNTRIES[@]}"; do
    country_lower=$(echo "$country" | tr '[:upper:]' '[:lower:]')
    url="https://www.ipdeny.com/ipblocks/data/countries/${country_lower}.zone"
    
    echo -n " -> Downloading zone for ${country:u}... "
    
    if curl --output /dev/null --silent --head --fail "$url"; then
        curl -s "$url" | sed "s/^/add $IPSET_NAME /" | ipset restore -!
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED (Invalid code?)${NC}"
    fi
done


echo -e "${YELLOW}[*] Applying iptables rules...${NC}"

iptables -N $CHAIN_NAME 2>/dev/null || iptables -F $CHAIN_NAME

iptables -A $CHAIN_NAME -m set --match-set $IPSET_NAME src -j ACCEPT

iptables -A $CHAIN_NAME -j DROP

for proto in "${PROTOCOLS[@]}"; do
    for port in "${TARGET_PORTS[@]}"; do
        check_rule=$(iptables -C INPUT -p $proto --dport $port -j $CHAIN_NAME 2>&1)
        
        if [[ $check_rule == *"iptables: Bad rule"* || $check_rule == *"No chain/target"* ]]; then
            echo -e " -> Protecting ${GREEN}$port/$proto${NC}"
            iptables -I INPUT -p $proto --dport $port -j $CHAIN_NAME
        else
            echo -e " -> Rule for $port/$proto already active."
        fi
    done
done



if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo -e "${GREEN}Rules saved via netfilter-persistent.${NC}"
elif command -v iptables-save &> /dev/null; then

    echo -e "${YELLOW}[!] Warning: 'netfilter-persistent' not found.${NC}"
    echo "    Rules applied but might be lost after reboot."
    echo "    Consider installing 'iptables-persistent'."
    echo "    apt install iptables-persistent"
fi

echo -e  "${GREEN}DONE${NC}"
echo -e "Only IPs from [${ALLOWED_COUNTRIES[*]}] can access ports [${TARGET_PORTS[*]}]."
