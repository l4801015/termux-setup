# Termux Development Setup

One-command configuration for Termux with development essentials.

## Installation
```bash
pkg update -y && \
pkg upgrade -y && \
pkg install git -y && \
git clone https://github.com/l4801015/termux-setup.git && \
cd termux-setup && \
chmod +x termux-setup.sh && \
./termux-setup.sh