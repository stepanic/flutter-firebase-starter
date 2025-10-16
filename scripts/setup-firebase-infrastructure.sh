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
# Initialize Pulumi stack
# ============================================================================

STACK_NAME="${PROJECT_NAME}-infra"

print_step "Initializing Pulumi stack: $STACK_NAME"

# Try to create or select stack
if pulumi stack select "$STACK_NAME" --non-interactive 2>/dev/null; then
    print_success "Using existing stack: $STACK_NAME"
elif pulumi stack init "$STACK_NAME" --non-interactive 2>/dev/null; then
    print_success "Created new stack: $STACK_NAME"
elif pulumi stack select "$PULUMI_USER/$STACK_NAME" --non-interactive 2>/dev/null; then
    print_success "Using existing stack: $PULUMI_USER/$STACK_NAME"
elif pulumi stack init "$PULUMI_USER/$STACK_NAME" --non-interactive 2>/dev/null; then
    print_success "Created new stack: $PULUMI_USER/$STACK_NAME"
else
    print_error "Failed to create or select Pulumi stack"
    exit 1
fi

# ============================================================================
# Configure Pulumi stack
# ============================================================================

print_step "Configuring Pulumi stack..."

# Required configs
pulumi config set projectBaseName "$FIREBASE_PROJECT_BASE"
pulumi config set organization "$ORGANIZATION"
pulumi config set environments "[\"$(echo $ENVIRONMENTS | sed 's/,/","/g')\"]"
pulumi config set githubRepo "$GITHUB_REPO"
pulumi config set androidPackageName "$ANDROID_PACKAGE"
pulumi config set iosBundleId "$IOS_BUNDLE"

# Optional configs (only set if provided)
if [[ -n "$GCP_BILLING_ACCOUNT" ]]; then
    pulumi config set gcpBillingAccount "$GCP_BILLING_ACCOUNT" --secret
fi

if [[ -n "$GCP_ORG_ID" ]]; then
    pulumi config set gcpOrganizationId "$GCP_ORG_ID"
fi

# Feature flags (defaults to true)
pulumi config set enableAuth true
pulumi config set enableFirestore true
pulumi config set enableFunctions true
pulumi config set enableStorage true
pulumi config set enableHosting false

# Regions
pulumi config set firestoreRegion "$FIRESTORE_REGION"
pulumi config set firebaseFunctionsRegion "$FUNCTIONS_REGION"

# Get GitHub token
GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
if [[ -n "$GITHUB_TOKEN" ]]; then
    pulumi config set githubToken "$GITHUB_TOKEN" --secret
else
    print_warning "GitHub token not found, GitHub secrets won't be configured"
fi

print_success "Configuration complete"

# ============================================================================
# Show configuration
# ============================================================================

echo ""
print_step "Current stack configuration:"
pulumi config --show-secrets

echo ""
print_warning "Review the configuration above before proceeding"
echo ""
read -p "Continue with deployment? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# ============================================================================
# Deploy infrastructure
# ============================================================================

print_step "Deploying Firebase infrastructure (this may take 5-10 minutes)..."
echo ""

pulumi up --yes

# ============================================================================
# Export outputs
# ============================================================================

print_step "Exporting outputs..."

OUTPUT_FILE="$ROOT_DIR/firebase-infrastructure-outputs.json"
pulumi stack output --json > "$OUTPUT_FILE"

print_success "Outputs saved to: $OUTPUT_FILE"

# ============================================================================
# Summary
# ============================================================================

print_header "🎉 Infrastructure Deployment Complete!"

echo ""
echo "Firebase projects created:"
for env in $(echo $ENVIRONMENTS | tr ',' ' '); do
    echo "  ✅ ${FIREBASE_PROJECT_BASE}-${env}"
done

echo ""
echo "Outputs exported to:"
echo "  📄 $OUTPUT_FILE"

echo ""
echo "Next steps:"
echo "  1. Review outputs: cat $OUTPUT_FILE | jq"
echo "  2. Copy Firebase config files to your Flutter project"
echo "  3. Run your Flutter app: flutter run --flavor dev"

echo ""
print_success "All done! 🚀"
