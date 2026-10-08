#!/usr/bin/env bash
# =============================================================================
# Automated Threat Intelligence Setup (VirusTotal & Active Response) for Wazuh
# Usage: sudo bash setup-threat-intel.sh
# =============================================================================
set -euo pipefail

C_RESET='\033[0m'; C_BOLD='\033[1m'
C_GREEN='\033[0;32m'; C_RED='\033[0;31m'; C_YELLOW='\033[1;33m'; C_CYAN='\033[0;36m'

echo -e "${C_BOLD}${C_CYAN}=== Wazuh Threat Intelligence Setup (VirusTotal & Active Response) ===${C_RESET}\n"

if [[ $EUID -ne 0 ]]; then
   echo -e "${C_RED}[!] This script must be run as root (or with sudo).${C_RESET}"
   exit 1
fi

OSSEC_CONF="/var/ossec/etc/ossec.conf"

# 1. Prompt for VirusTotal API Key
VT_KEY="${VIRUSTOTAL_API_KEY:-}"

if [[ -z "$VT_KEY" ]]; then
    read -rp "Enter your VirusTotal API Key (or press Enter to configure later): " VT_KEY
fi

VT_KEY="${VT_KEY:-YOUR_VIRUSTOTAL_API_KEY}"

# 2. Check if VirusTotal integration already exists in ossec.conf
if grep -q "<name>virustotal</name>" "$OSSEC_CONF"; then
    echo -e "${C_YELLOW}[!] VirusTotal integration is already present in ${OSSEC_CONF}.${C_RESET}"
else
    echo -e "${C_YELLOW}[+] Adding VirusTotal integration block to ${OSSEC_CONF}...${C_RESET}"
    sed -i "/<\/ossec_config>/i \
  <!-- Threat Intelligence: VirusTotal Integration -->\n\
  <integration>\n\
    <name>virustotal<\/name>\n\
    <api_key>${VT_KEY}<\/api_key>\n\
    <rule_id>100200,100201<\/rule_id>\n\
    <alert_format>json<\/alert_format>\n\
  <\/integration>\n" "$OSSEC_CONF"
    echo -e "${C_GREEN}[✔] VirusTotal configuration added.${C_RESET}"
fi

# 3. Check if remove-threat Active Response exists
if grep -q "<name>remove-threat</name>" "$OSSEC_CONF"; then
    echo -e "${C_YELLOW}[!] remove-threat Active Response is already present in ${OSSEC_CONF}.${C_RESET}"
else
    echo -e "${C_YELLOW}[+] Adding remove-threat Active Response blocks to ${OSSEC_CONF}...${C_RESET}"
    sed -i "/<\/ossec_config>/i \
  <!-- Active Response: remove-threat -->\n\
  <command>\n\
    <name>remove-threat<\/name>\n\
    <executable>remove-threat.sh<\/executable>\n\
    <timeout_allowed>no<\/timeout_allowed>\n\
  <\/command>\n\
  <active-response>\n\
    <disabled>no<\/disabled>\n\
    <command>remove-threat<\/command>\n\
    <location>local<\/location>\n\
    <rules_id>87105<\/rules_id>\n\
  <\/active-response>\n" "$OSSEC_CONF"
    echo -e "${C_GREEN}[✔] remove-threat Active Response configuration added.${C_RESET}"
fi

# 4. Restart Wazuh Manager
echo -e "\n${C_CYAN}[+] Restarting Wazuh Manager to apply Threat Intelligence integrations...${C_RESET}"
if systemctl is-active --quiet wazuh-manager; then
    systemctl restart wazuh-manager
    echo -e "${C_GREEN}[✔] Wazuh Manager restarted successfully!${C_RESET}"
else
    echo -e "${C_YELLOW}[!] Wazuh Manager is not running locally. Remember to restart wazuh-manager on your server.${C_RESET}"
fi

echo -e "\n${C_BOLD}${C_GREEN}Threat Intelligence setup complete!${C_RESET}"
