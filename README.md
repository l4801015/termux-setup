# Termux Development Setup

One-command configuration for Termux with development essentials.

## Installation
```bash
bash -c $'G="\e[32m";Y="\e[33m";R="\e[31m";X="\e[0m";if [ -d "$HOME/storage/downloads" ] && [ -w "$HOME/storage/downloads" ]; then echo -e "${G}✓ Storage active!$X";else echo -e "${Y}⚠ Starting setup...$X";termux-setup-storage;T=60;S=$(date +%s);while true; do N=$(date +%s);E=$((N-S));[ $E -ge $T ] && echo -e "\n${R}✗ Timeout!$X" && exit 1;[ -d "$HOME/storage/downloads" ] && [ -w "$HOME/storage/downloads" ] && echo -e "\n${G}✓ Activated!$X" && exit 0;printf "\r${Y}Time remaining: %02d:%02d$X" $(((T-E)/60)) $(((T-E)%60));sleep 1;done;fi'

( [ -d "$PREFIX" ] && \
  [ -d "/data/data/com.termux/files/usr" ] && \
  (pkg update -y && \
   pkg upgrade -y && \
   pkg install git -y) ) || \
(grep -q "Ubuntu" /etc/os-release 2>/dev/null && \
  (apt update -y && \
   apt upgrade -y && \
   apt install git -y) ) && \
git clone -b light/termux-setup \
  https://github.com/l4801015/termux-setup.git && \
cd termux-setup && \
chmod +x termux-setup.sh && \
./termux-setup.sh
```
