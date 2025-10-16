#!/bin/bash

# 🏗️ Firebase Infrastructure Setup with Pulumi
# This script sets up Firebase projects using Infrastructure as Code

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source helpers
source "$SCRIPT_DIR/helpers/print-helper.sh"

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Sets up Firebase infrastructure using Pulumi IaC.

REQUIRED OPTIONS:
    -n, --name NAME              Project base name (e.g., my-app)
    -o, --org ORG                Organization (e.g., com.mycompany)
    -g, --github REPO            GitHub repository (username/repo)

OPTIONAL:
    -b, --billing ACCOUNT        GCP Billing Account ID
    --org-id ID                  GCP Organization ID
    -e, --environments ENVS      Comma-separated environments [default: dev,staging,prod]
    --android-package PKG        Android package name [default: ORG.NAME]
    --ios-bundle ID              iOS bundle ID [default: ORG.NAME]
    --firestore-region REGION    Firestore region [default: eur3]
    --functions-region REGION    Functions region [default: europe-west1]
    -h, --help                   Show this help

EXAMPLES:
    # Minimal (required only)
    $0 --name my-app --org com.mycompany --github user/repo

    # With billing account
    $0 --name my-app --org com.mycompany --github user/repo \\
       --billing 014F20-5FFE71-0B734F

    # Custom environments
    $0 --name my-app --org com.mycompany --github user/repo \\
       --environments dev,qa,staging,prod

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -o|--org)
            ORGANIZATION="$2"
            shift 2
            ;;
        -g|--github)
            GITHUB_REPO="$2"
            shift 2
            ;;
        -b|--billing)
            GCP_BILLING_ACCOUNT="$2"
            shift 2
            ;;
        --org-id)
            GCP_ORG_ID="$2"
            shift 2
            ;;
        -e|--environments)
            ENVIRONMENTS="$2"
            shift 2
            ;;
        --android-package)
            ANDROID_PACKAGE="$2"
            shift 2
            ;;
        --ios-bundle)
            IOS_BUNDLE="$2"
            shift 2
            ;;
        --firestore-region)
            FIRESTORE_REGION="$2"
            shift 2
            ;;
        --functions-region)
            FUNCTIONS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$PROJECT_NAME" ]] || [[ -z "$ORGANIZATION" ]] || [[ -z "$GITHUB_REPO" ]]; then
    print_error "Missing required parameters!"
    echo ""
    echo "Required:"
    echo "  --name          Project name"
    echo "  --org           Organization"
    echo "  --github        GitHub repository"
    echo ""
    usage
fi

# Set defaults
ENVIRONMENTS="${ENVIRONMENTS:-dev,staging,prod}"
ANDROID_PACKAGE="${ANDROID_PACKAGE:-${ORGANIZATION}.${PROJECT_NAME}}"
IOS_BUNDLE="${IOS_BUNDLE:-${ORGANIZATION}.${PROJECT_NAME}}"
FIRESTORE_REGION="${FIRESTORE_REGION:-eur3}"
FUNCTIONS_REGION="${FUNCTIONS_REGION:-europe-west1}"

# Firebase project base name (replace underscores with hyphens)
FIREBASE_PROJECT_BASE="${PROJECT_NAME//_/-}"

print_header "Firebase Infrastructure Setup"

echo ""
print_info "Configuration:"
echo "  Project Base:       $FIREBASE_PROJECT_BASE"
echo "  Organization:       $ORGANIZATION"
echo "  GitHub Repo:        $GITHUB_REPO"
echo "  Environments:       $ENVIRONMENTS"
echo "  Android Package:    $ANDROID_PACKAGE"
echo "  iOS Bundle ID:      $IOS_BUNDLE"
echo "  Firestore Region:   $FIRESTORE_REGION"
echo "  Functions Region:   $FUNCTIONS_REGION"
[[ -n "$GCP_BILLING_ACCOUNT" ]] && echo "  Billing Account:    $GCP_BILLING_ACCOUNT"
[[ -n "$GCP_ORG_ID" ]] && echo "  GCP Org ID:         $GCP_ORG_ID"
echo ""

# ============================================================================
# Check Pulumi
# ============================================================================

if ! command -v pulumi &>/dev/null; then
    print_error "Pulumi not installed!"
    print_info "Install: curl -fsSL https://get.pulumi.com | sh"
    exit 1
fi

# Check Pulumi login
PULUMI_USER=$(pulumi whoami 2>/dev/null || echo "")

if [[ -z "$PULUMI_USER" ]]; then
    print_warning "Not logged into Pulumi"
    echo ""
    echo "Choose Pulumi backend:"
    echo "  1) Pulumi Cloud (requires account at app.pulumi.com)"
    echo "  2) Local backend (no account needed, state stored locally)"
    echo ""
    read -p "Choice [1 or 2]: " PULUMI_CHOICE

    if [[ "$PULUMI_CHOICE" == "2" ]]; then
        print_step "Using local Pulumi backend..."
        pulumi login --local
    else
        print_step "Login to Pulumi Cloud..."
        pulumi login
    fi

    PULUMI_USER=$(pulumi whoami)
fi

print_success "Pulumi user: $PULUMI_USER"

# ============================================================================
# Setup Pulumi project
# ============================================================================

cd "$ROOT_DIR/infrastructure/pulumi"

# Install dependencies
if [ ! -d "node_modules" ]; then
    print_step "Installing Pulumi dependencies..."
    npm install
else
    print_success "Dependencies already installed"
fi

# ============================================================================
# Create configuration file for TypeScript CLI
# ============================================================================

print_step "Preparing deployment configuration..."

# Convert comma-separated environments to JSON array
IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"
ENVS_JSON="["
FIRST=true
for env in "${ENV_ARRAY[@]}"; do
    if [ "$FIRST" = true ]; then
        ENVS_JSON+="\"$env\""
        FIRST=false
    else
        ENVS_JSON+=",\"$env\""
    fi
done
ENVS_JSON+="]"

# Get GitHub token
GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
if [[ -z "$GITHUB_TOKEN" ]]; then
    print_warning "GitHub token not found, GitHub secrets won't be configured"
fi

# Create temporary config file for TypeScript CLI
CONFIG_FILE=$(mktemp)
cat > "$CONFIG_FILE" << EOF
{
  "projectBaseName": "$FIREBASE_PROJECT_BASE",
  "organization": "$ORGANIZATION",
  "environments": $ENVS_JSON,
  "githubRepo": "$GITHUB_REPO",
  "androidPackageName": "$ANDROID_PACKAGE",
  "iosBundleId": "$IOS_BUNDLE",
  "gcpBillingAccount": "$GCP_BILLING_ACCOUNT",
  "gcpOrganizationId": "$GCP_ORG_ID",
  "githubToken": "$GITHUB_TOKEN",
  "firestoreRegion": "$FIRESTORE_REGION",
  "firebaseFunctionsRegion": "$FUNCTIONS_REGION",
  "enableAuth": true,
  "enableFirestore": true,
  "enableFunctions": true,
  "enableStorage": true,
  "enableHosting": false
}
EOF

print_success "Configuration prepared"

echo ""
print_info "Configuration summary:"
echo "  Project Base:       $FIREBASE_PROJECT_BASE"
echo "  Organization:       $ORGANIZATION"
echo "  Environments:       ${ENV_ARRAY[@]}"
echo "  GitHub Repo:        $GITHUB_REPO"
echo "  Firestore Region:   $FIRESTORE_REGION"
echo "  Functions Region:   $FUNCTIONS_REGION"
[[ -n "$GCP_BILLING_ACCOUNT" ]] && echo "  Billing Account:    $GCP_BILLING_ACCOUNT"
[[ -n "$GCP_ORG_ID" ]] && echo "  GCP Org ID:         $GCP_ORG_ID"

echo ""
print_warning "Review the configuration above before proceeding"
echo ""
read -p "Continue with deployment? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    print_warning "Deployment cancelled"
    rm -f "$CONFIG_FILE"
    exit 0
fi

# ============================================================================
# Deploy infrastructure using TypeScript CLI
# ============================================================================

print_step "Deploying Firebase infrastructure using TypeScript CLI..."
echo ""

# Run TypeScript CLI
npm run cli deploy "$CONFIG_FILE"

# Clean up temp file
rm -f "$CONFIG_FILE"

echo ""
print_success "Deployment complete! Check the output above for details."
