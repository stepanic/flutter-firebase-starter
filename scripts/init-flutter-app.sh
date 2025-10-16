#!/bin/bash

# 🚀 Complete Flutter + Firebase App Initialization
# This script automates EVERYTHING:
# - Flutter project creation
# - 3 Firebase projects (dev/staging/prod) via IaC
# - GitHub repository setup
# - All secrets configured automatically
# - First commit and push
# - CI/CD ready to go!

set -e

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Creates a new Flutter + Firebase project with complete CI/CD setup.

OPTIONS:
    -n, --name NAME              Project name (lowercase, underscores)
    -o, --org ORG                Organization (reverse domain, e.g., com.mycompany)
    -d, --desc DESCRIPTION       Project description
    -g, --github REPO            GitHub repository (username/repo-name)
    -t, --target DIR             Target directory [default: ..]
    -b, --billing ACCOUNT        GCP Billing Account ID (optional)
    --use-iac                    Use Pulumi IaC for Firebase setup
    --no-iac                     Skip IaC, manual Firebase setup
    -y, --yes                    Skip all confirmations
    -h, --help                   Show this help message

EXAMPLES:
    # Interactive mode (default)
    $0

    # Non-interactive with all parameters
    $0 --name my_app --org com.mycompany --desc "My App" \\
       --github username/my-app --use-iac --yes

    # Specify target directory
    $0 --name my_app --org com.mycompany --desc "My App" \\
       --github username/my-app --target ~/projects

EOF
    exit 0
}

# Parse command line arguments
INTERACTIVE=true
AUTO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            PROJECT_NAME="$2"
            INTERACTIVE=false
            shift 2
            ;;
        -o|--org)
            ORGANIZATION="$2"
            INTERACTIVE=false
            shift 2
            ;;
        -d|--desc)
            DESCRIPTION="$2"
            INTERACTIVE=false
            shift 2
            ;;
        -g|--github)
            GITHUB_REPO="$2"
            INTERACTIVE=false
            shift 2
            ;;
        -t|--target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -b|--billing)
            GCP_BILLING_ACCOUNT="$2"
            shift 2
            ;;
        --use-iac)
            USE_IAC=true
            shift
            ;;
        --no-iac)
            USE_IAC=false
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source helpers
source "$SCRIPT_DIR/helpers/print-helper.sh"
source "$SCRIPT_DIR/helpers/validation-helper.sh"

# Banner
clear
print_banner "Flutter Firebase Starter" "Complete Automated Setup"

# ============================================================================
# STEP 1: Prerequisites Check
# ============================================================================

print_header "Step 1: Checking Prerequisites"

check_command "flutter" "Flutter SDK"
check_command "dart" "Dart SDK"
check_command "git" "Git"
check_command "node" "Node.js"
check_command "npm" "npm"
check_command "gh" "GitHub CLI"
check_command "gcloud" "Google Cloud SDK"
check_command "firebase" "Firebase CLI"

# Optional: Check for Pulumi
if [[ -z "$USE_IAC" ]]; then
    USE_IAC=false
    if check_command_optional "pulumi" "Pulumi"; then
        echo -e "\n${YELLOW}Use Infrastructure as Code (Pulumi) for Firebase setup? (y/n)${NC}"
        read -p "> " USE_IAC_INPUT
        if [[ "$USE_IAC_INPUT" == "y" ]]; then
            USE_IAC=true
            print_success "Will use Pulumi for automated Firebase setup"

            # Check Pulumi login
            if ! pulumi whoami &>/dev/null; then
                print_warning "Not logged into Pulumi"
                echo ""
                echo -e "${YELLOW}Choose Pulumi backend:${NC}"
                echo "  1) Pulumi Cloud (requires account at app.pulumi.com)"
                echo "  2) Local backend (no account needed, state stored locally)"
                echo ""
                read -p "Choice [1 or 2]: " PULUMI_CHOICE

                if [[ "$PULUMI_CHOICE" == "2" ]]; then
                    print_step "Using local Pulumi backend..."
                    pulumi login --local
                    print_success "Pulumi configured with local backend"
                else
                    print_step "Login to Pulumi Cloud..."
                    pulumi login
                fi
            fi
        fi
    fi
fi

print_success "All prerequisites met!"

# ============================================================================
# STEP 2: Project Configuration
# ============================================================================

print_header "Step 2: Project Configuration"

# Target directory (ask if not provided via CLI)
if [[ -z "$TARGET_DIR" ]]; then
    print_step "Where do you want to create the project?"
    print_info "Examples:"
    print_info "  . (current directory)"
    print_info "  .. (parent directory)"
    print_info "  ~/projects (absolute path)"
    print_info "  /Users/username/projects (absolute path)"
    echo ""
    read -p "Target directory [default: ..]: " TARGET_DIR
fi

# Default to parent directory if empty
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR=".."
fi

# Expand tilde and make absolute path
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")"

print_info "Projects will be created in: $TARGET_DIR"

# Project name (ask if not provided via CLI)
if [[ -z "$PROJECT_NAME" ]]; then
    echo ""
    print_step "Enter project name (lowercase, underscores only):"
    read -p "> " PROJECT_NAME
fi
validate_project_name "$PROJECT_NAME"

# Organization (ask if not provided via CLI)
if [[ -z "$ORGANIZATION" ]]; then
    print_step "Enter organization (reverse domain, e.g., com.mycompany):"
    read -p "> " ORGANIZATION
fi
validate_organization "$ORGANIZATION"

# Description (ask if not provided via CLI)
if [[ -z "$DESCRIPTION" ]]; then
    print_step "Enter project description:"
    read -p "> " DESCRIPTION
fi

# GitHub repository (ask if not provided via CLI)
if [[ -z "$GITHUB_REPO" ]]; then
    print_step "Enter GitHub repository (username/repo-name):"
    print_info "Example: johndoe/my-awesome-app"
    read -p "> " GITHUB_REPO
fi
validate_github_repo "$GITHUB_REPO"

# Firebase project base name
FIREBASE_PROJECT_BASE="${PROJECT_NAME//_/-}"  # Replace underscores with hyphens
print_info "Firebase projects will be named: ${FIREBASE_PROJECT_BASE}-dev, ${FIREBASE_PROJECT_BASE}-staging, ${FIREBASE_PROJECT_BASE}-prod"

# GCP Billing Account (only if using IaC and not provided)
if [[ "$USE_IAC" == "true" ]] && [[ -z "$GCP_BILLING_ACCOUNT" ]]; then
    print_step "Enter GCP Billing Account ID (optional, press Enter to skip):"
    print_info "Format: 01234567-89ABCD-EF0123"
    read -p "> " GCP_BILLING_ACCOUNT
fi

# Confirm (skip if --yes flag provided)
if [[ "$AUTO_CONFIRM" != "true" ]]; then
    echo ""
    print_info "Configuration Summary:"
    echo -e "${CYAN}  Project Name:     ${NC}$PROJECT_NAME"
    echo -e "${CYAN}  Organization:     ${NC}$ORGANIZATION"
    echo -e "${CYAN}  Description:      ${NC}$DESCRIPTION"
    echo -e "${CYAN}  GitHub Repo:      ${NC}$GITHUB_REPO"
    echo -e "${CYAN}  Firebase Projects:${NC} ${FIREBASE_PROJECT_BASE}-{dev,staging,prod}"
    echo -e "${CYAN}  Use IaC:          ${NC}$USE_IAC"
    echo ""

    echo -e "${YELLOW}Continue with this configuration? (y/n)${NC}"
    read -p "> " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        print_error "Setup cancelled"
        exit 1
    fi
else
    print_info "Auto-confirm enabled, skipping confirmation"
fi

# ============================================================================
# STEP 3: Create Flutter Project
# ============================================================================

print_header "Step 3: Creating Flutter Project"

# Full path to new project
PROJECT_PATH="$TARGET_DIR/$PROJECT_NAME"

if [ -d "$PROJECT_PATH" ]; then
    print_error "Directory $PROJECT_PATH already exists!"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

print_step "Creating Flutter project in: $PROJECT_PATH"
print_info "This may take 1-2 minutes..."

cd "$TARGET_DIR"

flutter create \
    --org "$ORGANIZATION" \
    --description "$DESCRIPTION" \
    --platforms android,ios,web,linux,macos,windows \
    "$PROJECT_NAME"

cd "$PROJECT_NAME"
print_success "Flutter project created at: $(pwd)"

# ============================================================================
# STEP 4: Setup Project Structure
# ============================================================================

print_header "Step 4: Setting Up Project Structure"

# Copy template files (including hidden files like .github)
print_step "Copying project template..."
if [ -d "$ROOT_DIR/templates/flutter-app" ]; then
    # Copy all files including hidden ones
    shopt -s dotglob
    cp -r "$ROOT_DIR/templates/flutter-app/"* . 2>/dev/null || true
    shopt -u dotglob
    print_success "Template files copied"
else
    print_warning "Template directory not found, skipping"
fi

# Create directory structure
mkdir -p lib/{config,core,features,shared}
mkdir -p lib/core/{constants,utils,services,models}
mkdir -p lib/features/{auth,home}
mkdir -p lib/shared/{widgets,theme}
mkdir -p test/{unit,widget,integration}
mkdir -p assets/{images,fonts,icons}
mkdir -p firebase/{dev,staging,prod}

print_success "Project structure created"

# ============================================================================
# STEP 5: Configure Flavors
# ============================================================================

print_header "Step 5: Configuring Flavors (dev/staging/prod)"

# Run flavor configuration script
bash "$SCRIPT_DIR/helpers/configure-flavors.sh" "$PROJECT_NAME" "$ORGANIZATION"

print_success "Flavors configured for Android and iOS"

# ============================================================================
# STEP 6: Setup Firebase Projects
# ============================================================================

print_header "Step 6: Setting Up Firebase Projects"

if [[ "$USE_IAC" == "true" ]]; then
    # Use Pulumi for automated setup
    print_step "Using Infrastructure as Code (Pulumi) for Firebase setup..."

    cd "$ROOT_DIR/infrastructure/pulumi"

    # Install dependencies
    print_step "Installing Pulumi dependencies..."
    npm install

    # Get current Pulumi user
    PULUMI_USER=$(pulumi whoami 2>/dev/null || echo "")

    if [[ -z "$PULUMI_USER" ]]; then
        print_error "Not logged into Pulumi!"
        print_info "Please run: pulumi login"
        exit 1
    fi

    print_info "Pulumi user: $PULUMI_USER"

    # Initialize Pulumi stack (local backend or personal account)
    STACK_NAME="${PROJECT_NAME}-infra"

    print_step "Initializing Pulumi stack: $STACK_NAME"

    # Try to create stack, if it fails, try to select it
    if pulumi stack init "$STACK_NAME" --non-interactive 2>/dev/null; then
        print_success "Pulumi stack created: $STACK_NAME"
    elif pulumi stack select "$STACK_NAME" --non-interactive 2>/dev/null; then
        print_success "Using existing Pulumi stack: $STACK_NAME"
    else
        print_error "Failed to create or select Pulumi stack"
        print_info "Trying with full stack name: $PULUMI_USER/$STACK_NAME"

        # Try with user prefix
        if pulumi stack init "$PULUMI_USER/$STACK_NAME" --non-interactive 2>/dev/null; then
            print_success "Pulumi stack created: $PULUMI_USER/$STACK_NAME"
        elif pulumi stack select "$PULUMI_USER/$STACK_NAME" --non-interactive 2>/dev/null; then
            print_success "Using existing stack: $PULUMI_USER/$STACK_NAME"
        else
            print_error "Cannot create Pulumi stack"
            print_info "You may need to:"
            print_info "  1. Check Pulumi login: pulumi whoami"
            print_info "  2. Or use local backend: pulumi login --local"
            exit 1
        fi
    fi

    # Set configuration
    pulumi config set projectBaseName "$FIREBASE_PROJECT_BASE"
    pulumi config set organization "$ORGANIZATION"
    pulumi config set environments '["dev","staging","prod"]'
    pulumi config set githubRepo "$GITHUB_REPO"
    pulumi config set androidPackageName "${ORGANIZATION}.${PROJECT_NAME}"
    pulumi config set iosBundleId "${ORGANIZATION}.${PROJECT_NAME}"

    if [[ -n "$GCP_BILLING_ACCOUNT" ]]; then
        pulumi config set gcpBillingAccount "$GCP_BILLING_ACCOUNT" --secret
    fi

    # Get GitHub token
    GITHUB_TOKEN=$(gh auth token)
    pulumi config set githubToken "$GITHUB_TOKEN" --secret

    # Deploy infrastructure
    print_step "Deploying Firebase infrastructure (this may take 5-10 minutes)..."
    pulumi up --yes --skip-preview

    # Export outputs to files
    pulumi stack output --json > "$PROJECT_PATH/firebase-outputs.json"

    cd "$PROJECT_PATH"

    print_success "Firebase projects created via IaC!"
    print_info "Firebase configurations saved to firebase-outputs.json"

else
    # Manual Firebase setup with guided steps
    print_warning "IaC not used. You'll need to create Firebase projects manually."
    print_info "Run: bash $SCRIPT_DIR/helpers/setup-firebase-manual.sh"

    # For now, create placeholder instructions
    cat > FIREBASE_SETUP_INSTRUCTIONS.md << 'EOF'
# Firebase Setup Instructions

Since Infrastructure as Code (Pulumi) was not used, you need to set up Firebase projects manually.

## Steps:

### 1. Create Firebase Projects

Go to https://console.firebase.google.com/ and create three projects:
- `${FIREBASE_PROJECT_BASE}-dev`
- `${FIREBASE_PROJECT_BASE}-staging`
- `${FIREBASE_PROJECT_BASE}-prod`

### 2. Enable Services

For each project, enable:
- ✅ Firebase Authentication
- ✅ Cloud Firestore
- ✅ Cloud Functions
- ✅ Cloud Storage

### 3. Register Apps

For each project, register:
- Android app with package names:
  - Dev: `${ORGANIZATION}.${PROJECT_NAME}.dev`
  - Staging: `${ORGANIZATION}.${PROJECT_NAME}.staging`
  - Prod: `${ORGANIZATION}.${PROJECT_NAME}`

- iOS app with bundle IDs:
  - Dev: `${ORGANIZATION}.${PROJECT_NAME}.dev`
  - Staging: `${ORGANIZATION}.${PROJECT_NAME}.staging`
  - Prod: `${ORGANIZATION}.${PROJECT_NAME}`

### 4. Download Configuration Files

Download and place:
- `google-services.json` → `android/app/src/{dev,staging,prod}/`
- `GoogleService-Info.plist` → `ios/Runner/{dev,staging,prod}/`

### 5. Setup GitHub Secrets

Run: `bash scripts/setup-github-secrets.sh`

EOF

    print_info "Instructions saved to FIREBASE_SETUP_INSTRUCTIONS.md"
fi

# ============================================================================
# STEP 7: Initialize Git and GitHub
# ============================================================================

print_header "Step 7: Setting Up Git and GitHub"

# Initialize git
if [ ! -d ".git" ]; then
    git init
    print_success "Git repository initialized"
fi

# Create .gitignore
cat > .gitignore << 'EOGITIGNORE'
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.buildlog/
.history
.svn/
migrate_working_dir/

# IntelliJ
*.iml
*.ipr
*.iws
.idea/

# Flutter/Dart/Pub
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
/build/

# Android
/android/app/debug
/android/app/profile
/android/app/release

# iOS/XCode
**/ios/**/*.mode1v3
**/ios/**/*.mode2v3
**/ios/**/*.moved-aside
**/ios/**/*.pbxuser
**/ios/**/*.perspectivev3
**/ios/**/*sync/
**/ios/**/.sconsign.dblite
**/ios/**/.tags*
**/ios/**/.vagrant/
**/ios/**/DerivedData/
**/ios/**/Icon?
**/ios/**/Pods/
**/ios/**/.symlinks/
**/ios/**/profile
**/ios/**/xcuserdata
**/ios/.generated/
**/ios/Flutter/.last_build_id
**/ios/Flutter/App.framework
**/ios/Flutter/Flutter.framework
**/ios/Flutter/Flutter.podspec
**/ios/Flutter/Generated.xcconfig
**/ios/Flutter/ephemeral
**/ios/Flutter/app.flx
**/ios/Flutter/app.zip
**/ios/Flutter/flutter_assets/
**/ios/Flutter/flutter_export_environment.sh
**/ios/ServiceDefinitions.json
**/ios/Runner/GeneratedPluginRegistrant.*

# Signing files
*.jks
*.p12
*.key
*.mobileprovision
*.certSigningRequest
key.properties
android/key.properties
**/key.properties

# Firebase
google-services.json
GoogleService-Info.plist
firebase-adminsdk-*.json
service-account-key.json
.firebase/
firebase-outputs.json

# Environment files
.env
.env.*
!.env.example

# Coverage
coverage/
*.lcov

# Build artifacts
*.apk
*.aab
*.ipa
*.app
*.exe
*.msix

# Generated files
*.g.dart
*.freezed.dart
*.mocks.dart

# IDE
.vscode/
.fleet/

# IaC outputs
*.tfstate
*.tfstate.*
.terraform/
.pulumi/
EOGITIGNORE

print_success ".gitignore created"

# Create GitHub repository or connect to existing
print_step "Setting up GitHub repository..."

REPO_EXISTS=false
if gh repo view "$GITHUB_REPO" &>/dev/null 2>&1; then
    REPO_EXISTS=true
    print_warning "Repository $GITHUB_REPO already exists"
fi

# Check if remote already exists
if git remote get-url origin &>/dev/null 2>&1; then
    print_info "Git remote 'origin' already configured"
    CURRENT_REMOTE=$(git remote get-url origin)
    print_info "Current remote: $CURRENT_REMOTE"
else
    # Add remote
    print_step "Adding GitHub remote..."
    if git remote add origin "git@github.com:$GITHUB_REPO.git" 2>/dev/null; then
        print_success "Remote added: git@github.com:$GITHUB_REPO.git"
    elif git remote add origin "https://github.com/$GITHUB_REPO.git" 2>/dev/null; then
        print_success "Remote added: https://github.com/$GITHUB_REPO.git"
    else
        print_error "Failed to add remote"
    fi
fi

# Create repo if it doesn't exist
if [[ "$REPO_EXISTS" == "false" ]]; then
    print_step "Creating GitHub repository..."
    if gh repo create "$GITHUB_REPO" --public --description "$DESCRIPTION" 2>/dev/null; then
        print_success "GitHub repository created: https://github.com/$GITHUB_REPO"
    else
        print_warning "Could not create repository automatically"
        print_info "You can create it manually at: https://github.com/new"
    fi
fi

# ============================================================================
# STEP 8: Initial Commit
# ============================================================================

print_header "Step 8: Creating Initial Commit"

git add .
git commit -m "🎉 Initial commit: Flutter project with Firebase setup

- Multi-platform Flutter app (Android, iOS, Web, Desktop)
- 3 environments configured (dev, staging, prod)
- Firebase integration ready
- CI/CD workflows configured
- Complete project structure

Generated by: Flutter Firebase Starter
https://github.com/yourusername/flutter-firebase-starter"

print_success "Initial commit created"

# ============================================================================
# STEP 9: Push to GitHub
# ============================================================================

print_header "Step 9: Pushing to GitHub"

git branch -M main
git push -u origin main

print_success "Code pushed to GitHub!"

# ============================================================================
# STEP 10: Final Summary
# ============================================================================

print_header "🎉 Setup Complete!"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📊 EXECUTION SUMMARY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Track what succeeded and what needs attention
COMPLETED_STEPS=()
WARNING_STEPS=()
FAILED_STEPS=()

# Step 1: Prerequisites
COMPLETED_STEPS+=("✅ Prerequisites checked and validated")

# Step 2: Configuration
COMPLETED_STEPS+=("✅ Project configuration collected")

# Step 3: Flutter project
if [ -d "$PROJECT_PATH" ]; then
    COMPLETED_STEPS+=("✅ Flutter project created at: $PROJECT_PATH")
else
    FAILED_STEPS+=("❌ Flutter project creation failed")
fi

# Step 4: Project structure
if [ -d "$PROJECT_PATH/lib/config" ]; then
    COMPLETED_STEPS+=("✅ Project structure and templates copied")
else
    WARNING_STEPS+=("⚠️  Project structure may be incomplete")
fi

# Step 5: Flavors
if [ -f "$PROJECT_PATH/lib/main_dev.dart" ]; then
    COMPLETED_STEPS+=("✅ Flavors configured (dev, staging, prod)")
else
    WARNING_STEPS+=("⚠️  Flavor configuration may be incomplete")
fi

# Step 6: Firebase setup
if [[ "$USE_IAC" == "true" ]]; then
    if [ -f "$PROJECT_PATH/firebase-outputs.json" ]; then
        COMPLETED_STEPS+=("✅ Firebase projects created via Infrastructure as Code")
        COMPLETED_STEPS+=("   → ${FIREBASE_PROJECT_BASE}-dev")
        COMPLETED_STEPS+=("   → ${FIREBASE_PROJECT_BASE}-staging")
        COMPLETED_STEPS+=("   → ${FIREBASE_PROJECT_BASE}-prod")
    else
        FAILED_STEPS+=("❌ Firebase IaC deployment failed or incomplete")
        WARNING_STEPS+=("⚠️  You may need to run infrastructure setup manually:")
        WARNING_STEPS+=("   → ./scripts/setup-firebase-infrastructure.sh")
    fi
else
    WARNING_STEPS+=("⚠️  Firebase projects NOT created (IaC not used)")
    WARNING_STEPS+=("   → Manual setup required - see FIREBASE_SETUP_INSTRUCTIONS.md")
fi

# Step 7: GitHub
if [ -d "$PROJECT_PATH/.git" ]; then
    COMPLETED_STEPS+=("✅ Git repository initialized")
else
    FAILED_STEPS+=("❌ Git repository initialization failed")
fi

# Check if GitHub repo exists
if gh repo view "$GITHUB_REPO" &>/dev/null; then
    COMPLETED_STEPS+=("✅ GitHub repository: https://github.com/$GITHUB_REPO")
else
    WARNING_STEPS+=("⚠️  GitHub repository may not be created")
fi

# Step 8: Initial commit
if git -C "$PROJECT_PATH" log --oneline 2>/dev/null | head -n 1 > /dev/null; then
    COMPLETED_STEPS+=("✅ Initial commit created")
else
    WARNING_STEPS+=("⚠️  Initial commit may not be created")
fi

# Step 9: Push to GitHub
if git -C "$PROJECT_PATH" remote get-url origin &>/dev/null; then
    COMPLETED_STEPS+=("✅ GitHub remote configured")
    # Check if pushed
    if git -C "$PROJECT_PATH" branch -r | grep -q "origin/main"; then
        COMPLETED_STEPS+=("✅ Code pushed to GitHub")
    else
        WARNING_STEPS+=("⚠️  Code may not be pushed to GitHub yet")
    fi
else
    WARNING_STEPS+=("⚠️  GitHub remote not configured")
fi

# Print completed steps
echo -e "${GREEN}✅ COMPLETED:${NC}"
echo ""
for step in "${COMPLETED_STEPS[@]}"; do
    echo -e "  $step"
done

# Print warnings if any
if [ ${#WARNING_STEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  WARNINGS / MANUAL STEPS NEEDED:${NC}"
    echo ""
    for step in "${WARNING_STEPS[@]}"; do
        echo -e "  $step"
    done
fi

# Print failures if any
if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ FAILED:${NC}"
    echo ""
    for step in "${FAILED_STEPS[@]}"; do
        echo -e "  $step"
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Final status
if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ SETUP COMPLETED WITH ERRORS${NC}"
    echo ""
    echo -e "${YELLOW}Some steps failed. Please review the errors above and fix them manually.${NC}"
    echo ""
elif [ ${#WARNING_STEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  SETUP COMPLETED WITH WARNINGS${NC}"
    echo ""
    echo -e "${YELLOW}Some steps require manual action. Please review the warnings above.${NC}"
    echo ""
else
    echo ""
    echo -e "${GREEN}✅ ✨ ALL DONE! SETUP COMPLETED SUCCESSFULLY! ✨ ✅${NC}"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Project details
cat << EOF
${CYAN}📁 Project Details:${NC}
   Name:     $PROJECT_NAME
   Location: $PROJECT_PATH
   GitHub:   https://github.com/$GITHUB_REPO

${CYAN}🔥 Firebase Projects:${NC}
   ${FIREBASE_PROJECT_BASE}-dev
   ${FIREBASE_PROJECT_BASE}-staging
   ${FIREBASE_PROJECT_BASE}-prod

${CYAN}📱 Configured Platforms:${NC}
   ✅ Android (3 flavors: dev, staging, prod)
   ✅ iOS (3 schemes: dev, staging, prod)
   ✅ Web
   ✅ Linux, macOS, Windows

${YELLOW}🚀 Next Steps:${NC}

${PURPLE}1. Install dependencies:${NC}
   cd $PROJECT_PATH
   flutter pub get

${PURPLE}2. Run the app (dev environment):${NC}
   flutter run --flavor dev -t lib/main_dev.dart

${PURPLE}3. Test everything works:${NC}
   flutter test

${PURPLE}4. Build for production:${NC}
   flutter build apk --flavor prod

${PURPLE}5. Monitor CI/CD:${NC}
   https://github.com/$GITHUB_REPO/actions

${BLUE}🎯 Quick Commands:${NC}

   ${PURPLE}Run dev:${NC}        flutter run --flavor dev -t lib/main_dev.dart
   ${PURPLE}Run staging:${NC}    flutter run --flavor staging -t lib/main_staging.dart
   ${PURPLE}Run prod:${NC}       flutter run --flavor prod -t lib/main_prod.dart

   ${PURPLE}Test:${NC}           flutter test
   ${PURPLE}Format:${NC}         dart format .
   ${PURPLE}Analyze:${NC}        flutter analyze

${BLUE}📚 Documentation:${NC}
   - README.md - Project overview
   - FIREBASE_SETUP_INSTRUCTIONS.md - Firebase setup (if IaC not used)
   - .github/workflows/ - CI/CD workflows

${GREEN}🎊 Happy Coding!${NC}

EOF

# Offer to open in editor (skip if auto-confirm)
if [[ "$AUTO_CONFIRM" != "true" ]]; then
    echo -e "${YELLOW}Open project in VS Code? (y/n)${NC}"
    read -p "> " OPEN_VSCODE

    if [[ "$OPEN_VSCODE" == "y" ]] && command -v code &> /dev/null; then
        code "$PROJECT_PATH"
        print_success "Project opened in VS Code"
    fi

    # Offer to run the app
    echo -e "\n${YELLOW}Run the app now (dev flavor)? (y/n)${NC}"
    read -p "> " RUN_APP

    if [[ "$RUN_APP" == "y" ]]; then
        print_step "Starting Flutter app..."
        cd "$PROJECT_PATH"
        flutter run --flavor dev -t lib/main_dev.dart
    fi
fi

# Final message
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ ✅ DONE! Your Flutter + Firebase project is ready! ✅ ✨${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi
