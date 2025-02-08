#!/bin/bash
set -eo pipefail

# Redirect all output to logs with timestamp
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0 }' | tee -a setup_output.log)
exec 2> >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0 }' | tee -a setup_errors.log >&2)

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Enhanced debug logging
debug_message() {
    echo -e "${GREEN}[${YELLOW}$(date +"%Y-%m-%d %H:%M:%S")${GREEN}]${BLUE} $1 ${RESET}"
}

# Process ancestry check for proot
check_proot_process() {
    local pid=$$
    while [ "$pid" -ne 1 ]; do
        if ps -p "$pid" -o comm= | grep -qi 'proot'; then
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
    done
    return 1
}

# Multi-layered environment detection
detect_environment() {
    # Check Termux first
    if [ -n "$TERMUX_VERSION" ] && [ -x "$PREFIX/bin/pkg" ]; then
        echo "termux"
        return
    fi

    # Proot environment checks
    local is_proot_env=false
    if check_proot_process; then
        is_proot_env=true
    elif [ -f "/proc/self/root/.proot-dir" ] || [ -d "/proc/sys/fs/binfmt_misc/proot" ]; then
        is_proot_env=true
    elif [ "$(stat -c %i /)" != "$(stat -c %i /proc/1/root/.)" ]; then
        is_proot_env=true
    fi

    if $is_proot_env; then
        # Verify Ubuntu
        if [ -f "/etc/os-release" ] && grep -qi 'ID=ubuntu' /etc/os-release && command -v apt >/dev/null; then
            echo "ubuntu_proot"
        else
            # Check for bind mounts as final verification
            if mount | grep -q 'bind.*/proc'; then
                echo "other_proot"
            else
                echo "unknown"
            fi
        fi
        return
    fi

    echo "unknown"
}

# Package manager configuration
setup_package_manager() {
    case $ENV_TYPE in
        "termux")
            debug_message "Configuring Termux packages"
            UPDATE_CMD="pkg update -y"
            INSTALL_CMD="pkg install -y"
            ;;
        "ubuntu_proot")
            debug_message "Configuring Ubuntu packages"
            UPDATE_CMD="apt update -y"
            INSTALL_CMD="apt install -y"
            
            # Ensure sudo availability
            if ! command -v sudo >/dev/null; then
                debug_message "Installing sudo"
                $INSTALL_CMD sudo
            fi
            ;;
        "other_proot")
            echo -e "${RED}Unsupported proot environment${RESET}" >&2
            exit 1
            ;;
        *)
            echo -e "${RED}Unrecognized execution environment${RESET}" >&2
            exit 1
            ;;
    esac
}

# Core package installation
install_core_packages() {
    local base_packages="git curl wget zsh neovim ncurses-utils"
    
    debug_message "Installing core packages"
    case $ENV_TYPE in
        "termux")
            $INSTALL_CMD $base_packages nodejs openssh proot-distro clang make
            ;;
        "ubuntu_proot")
            $INSTALL_CMD $base_packages nodejs npm build-essential proot
            ;;
    esac || {
        echo -e "${RED}Package installation failed${RESET}" >&2
        exit 1
    }
}

# Environment-specific configurations
configure_environment() {
    debug_message "Configuring environment specifics"
    
    # Truecolor support
    if ! grep -q "COLORTERM=truecolor" ~/.zshrc 2>/dev/null; then
        echo "export COLORTERM=truecolor" >> ~/.zshrc
    fi

    case $ENV_TYPE in
        "termux")
            # Termux-specific settings
            mkdir -p ~/.termux
            echo "termux-transient-keys = enter,arrow" >> ~/.termux/termux.properties
            termux-reload-settings
            ;;
        "ubuntu_proot")
            # Ubuntu proot optimizations
            echo "export PROOT_NO_SECCOMP=1" >> ~/.zshrc
            ;;
    esac
}

# Main execution flow
main() {
    debug_message "Starting environment detection"
    ENV_TYPE=$(detect_environment)
    debug_message "Detected environment: ${YELLOW}$ENV_TYPE${RESET}"

    setup_package_manager

    debug_message "Updating packages"
    $UPDATE_CMD || {
        echo -e "${RED}Failed to update packages${RESET}" >&2
        exit 1
    }

    install_core_packages
    configure_environment

    debug_message "${GREEN}Environment setup completed successfully${RESET}"
}

# Entry point
main "$@"
