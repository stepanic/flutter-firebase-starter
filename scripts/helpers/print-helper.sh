#!/bin/bash

# Print helper functions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_banner() {
    local title="$1"
    local subtitle="$2"

    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   🚀 FLUTTER FIREBASE STARTER                               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    if [[ -n "$title" ]]; then
        echo -e "${WHITE}${title}${NC}"
    fi
    if [[ -n "$subtitle" ]]; then
        echo -e "${CYAN}${subtitle}${NC}"
    fi
    echo ""
}

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${PURPLE}▶️  $1${NC}"
}

print_substep() {
    echo -e "   ${PURPLE}→ $1${NC}"
}
