#!/bin/bash

# 🔐 Switch All Accounts to Desired Google/GitHub Account
# Usage: ./scripts/switch-account.sh desired-email@gmail.com

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "${CYAN}▶️  $1${NC}"
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

# Check if email provided
if [ -z "$1" ]; then
    print_error "Please provide Google account email"
    echo ""
    echo "Usage: $0 your-email@gmail.com"
    echo ""
    exit 1
fi

DESIRED_EMAIL="$1"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  🔐 Account Switcher                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

print_step "Target account: $DESIRED_EMAIL"
echo ""

# ============================================================================
# 1. Google Cloud
# ============================================================================

print_step "Switching Google Cloud account..."

# Check if account exists in gcloud
if gcloud auth list --format="value(account)" | grep -q "$DESIRED_EMAIL"; then
    print_success "Account already authorized in gcloud"
    gcloud config set account "$DESIRED_EMAIL"
else
    print_warning "Account not found in gcloud, logging in..."
    gcloud auth login "$DESIRED_EMAIL"
fi

# Verify
CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ "$CURRENT_ACCOUNT" = "$DESIRED_EMAIL" ]; then
    print_success "Google Cloud account: $CURRENT_ACCOUNT"
else
    print_error "Failed to switch gcloud account"
    exit 1
fi

echo ""

# ============================================================================
# 2. Application Default Credentials
# ============================================================================

print_step "Setting up Application Default Credentials..."

echo ""
echo -e "${YELLOW}📱 A browser will open for OAuth authorization${NC}"
echo -e "${YELLOW}👉 Select: $DESIRED_EMAIL${NC}"
echo ""
read -p "Press Enter to continue..."

gcloud auth application-default login

# Verify
if gcloud auth application-default print-access-token > /dev/null 2>&1; then
    print_success "Application Default Credentials configured"
else
    print_error "Failed to configure ADC"
    exit 1
fi

echo ""

# ============================================================================
# 3. Firebase
# ============================================================================

print_step "Switching Firebase account..."

# Check if already logged in
if firebase login:list 2>/dev/null | grep -q "$DESIRED_EMAIL"; then
    print_success "Firebase already logged in with: $DESIRED_EMAIL"
else
    print_warning "Logging into Firebase..."

    echo ""
    echo -e "${YELLOW}📱 A browser will open for Firebase authorization${NC}"
    echo -e "${YELLOW}👉 Select: $DESIRED_EMAIL${NC}"
    echo ""
    read -p "Press Enter to continue..."

    firebase login --reauth
fi

print_success "Firebase account configured"

echo ""

# ============================================================================
# 4. Verification
# ============================================================================

print_step "Verifying all accounts..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Account Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1️⃣  Google Cloud:"
GCLOUD_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ "$GCLOUD_ACCOUNT" = "$DESIRED_EMAIL" ]; then
    echo -e "   ${GREEN}✅ $GCLOUD_ACCOUNT${NC}"
else
    echo -e "   ${RED}❌ $GCLOUD_ACCOUNT (expected: $DESIRED_EMAIL)${NC}"
fi

echo ""
echo "2️⃣  Application Default Credentials:"
if gcloud auth application-default print-access-token > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Configured${NC}"
else
    echo -e "   ${RED}❌ Not configured${NC}"
fi

echo ""
echo "3️⃣  Firebase:"
if firebase login:list 2>/dev/null | grep -q "$DESIRED_EMAIL"; then
    echo -e "   ${GREEN}✅ $DESIRED_EMAIL${NC}"
else
    echo -e "   ${YELLOW}⚠️  Not verified${NC}"
fi

echo ""
echo "4️⃣  GitHub:"
GH_ACCOUNT=$(gh api user --jq .login 2>/dev/null || echo "not logged in")
echo -e "   ${CYAN}ℹ️  $GH_ACCOUNT${NC}"

echo ""
echo "5️⃣  Pulumi:"
PULUMI_USER=$(pulumi whoami 2>/dev/null || echo "not logged in")
echo -e "   ${CYAN}ℹ️  $PULUMI_USER${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
# GitHub Note
# ============================================================================

echo ""
print_warning "GitHub and Pulumi accounts are NOT changed by this script"
echo ""
echo "If you need to switch GitHub account:"
echo "  ${CYAN}gh auth logout${NC}"
echo "  ${CYAN}gh auth login${NC}"
echo ""
echo "If you need to switch Pulumi account:"
echo "  ${CYAN}pulumi logout${NC}"
echo "  ${CYAN}pulumi login${NC}"
echo ""

# ============================================================================
# Final Message
# ============================================================================

echo -e "${GREEN}✅ Account switch complete!${NC}"
echo ""
echo "You can now run:"
echo "  ${CYAN}./scripts/init-flutter-app.sh${NC}"
echo ""
