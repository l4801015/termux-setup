# Termux Development Setup

One-command configuration for Termux with development essentials.

## Installation
```bash
( [ -d "$PREFIX" ] && \
  [ -d "/data/data/com.termux/files/usr" ] && \
  (pkg update -y && \
   pkg upgrade -y && \
   pkg install git -y) ) || \
(grep -q "Ubuntu" /etc/os-release 2>/dev/null && \
  (apt update -y && \
   apt upgrade -y && \
   apt install git -y) ) && \
git clone -b experiment/termux-setup \
  https://github.com/l4801015/termux-setup.git && \
cd termux-setup && \
chmod +x termux-setup.sh && \
./termux-setup.sh
```