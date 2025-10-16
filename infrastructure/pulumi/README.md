# 🏗️ Firebase Infrastructure as Code (Pulumi)

This directory contains Pulumi-based Infrastructure as Code for **completely automated** Firebase project setup.

## 🎯 What This Does

Automates the entire Firebase infrastructure setup:

✅ **Creates 3 GCP/Firebase projects** (dev, staging, prod)
✅ **Enables all required APIs** (Firebase, Firestore, Functions, Storage, Auth)
✅ **Registers Android & iOS apps** for each environment
✅ **Downloads configuration files** (google-services.json, GoogleService-Info.plist)
✅ **Creates service accounts** with proper IAM roles
✅ **Generates Android signing keys**
✅ **Configures GitHub Secrets** automatically
✅ **Deploys Security Rules** for Firestore and Storage

**Time saved: 2-3 hours of manual work → 5-10 minutes automated!**

## 📋 Prerequisites

### Required Tools

```bash
# Install Pulumi
curl -fsSL https://get.pulumi.com | sh

# Install Node.js 20+
# macOS:
brew install node@20

# Install Google Cloud SDK
brew install --cask google-cloud-sdk

# Install Firebase CLI
npm install -g firebase-tools

# Install GitHub CLI
brew install gh
```

### Required Accounts & Access

1. **Google Cloud Platform**
   - GCP account with billing enabled
   - Organization ID (optional, for enterprise)
   - Billing Account ID

2. **GitHub**
   - GitHub account
   - Personal Access Token with `repo` and `admin:repo_hook` scopes
   - Get token: https://github.com/settings/tokens

3. **Pulumi**
   - Pulumi account (free tier is enough)
   - Login: `pulumi login`

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd infrastructure/pulumi
npm install
```

### 2. Login to Services

```bash
# Login to Pulumi
pulumi login

# Login to Google Cloud
gcloud auth login
gcloud auth application-default login

# Login to GitHub
gh auth login

# Login to Firebase
firebase login
```

### 3. Initialize Pulumi Stack

```bash
# Create a new stack
pulumi stack init my-app-infra

# Or select existing stack
pulumi stack select my-app-infra
```

### 4. Configure Required Settings

```bash
# Project configuration
pulumi config set projectBaseName "my-app"
pulumi config set organization "com.mycompany"
pulumi config set environments '["dev","staging","prod"]'

# GitHub configuration
pulumi config set githubRepo "username/my-app-repo"
pulumi config set githubToken --secret "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# App configuration
pulumi config set androidPackageName "com.mycompany.myapp"
pulumi config set iosBundleId "com.mycompany.myapp"

# GCP configuration (optional)
pulumi config set gcpBillingAccount --secret "01234567-89ABCD-EF0123"
pulumi config set gcpOrganizationId "123456789012"

# Firebase configuration (optional, defaults shown)
pulumi config set enableAuth true
pulumi config set enableFirestore true
pulumi config set enableFunctions true
pulumi config set enableStorage true
pulumi config set enableHosting false

# Regions (optional, defaults to EU)
pulumi config set firebaseFunctionsRegion "europe-west1"
pulumi config set firestoreRegion "eur3"
```

### 5. Preview Changes

```bash
pulumi preview
```

This shows what will be created without actually creating anything.

### 6. Deploy Infrastructure

```bash
pulumi up
```

**This will:**
1. Create 3 Firebase projects
2. Enable all required APIs
3. Register Android & iOS apps
4. Download config files
5. Create service accounts
6. Generate Android signing keys
7. Configure ALL GitHub Secrets

**Duration: 5-10 minutes**

### 7. Export Outputs

```bash
# Export all outputs to JSON
pulumi stack output --json > firebase-outputs.json

# View specific outputs
pulumi stack output firebase_project_id_dev
pulumi stack output service_account_email_dev
pulumi stack output summary
```

## 📖 Configuration Reference

### Required Configuration

| Key | Description | Example |
|-----|-------------|---------|
| `projectBaseName` | Base name for Firebase projects | `my-app` |
| `organization` | Organization domain | `com.mycompany` |
| `githubRepo` | GitHub repository | `username/repo` |
| `githubToken` | GitHub personal access token (secret) | `ghp_xxxxx` |
| `androidPackageName` | Android package name base | `com.mycompany.myapp` |
| `iosBundleId` | iOS bundle ID base | `com.mycompany.myapp` |

### Optional Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `environments` | List of environments | `["dev","staging","prod"]` |
| `gcpBillingAccount` | GCP billing account ID (secret) | - |
| `gcpOrganizationId` | GCP organization ID | - |
| `enableAuth` | Enable Firebase Auth | `true` |
| `enableFirestore` | Enable Cloud Firestore | `true` |
| `enableFunctions` | Enable Cloud Functions | `true` |
| `enableStorage` | Enable Cloud Storage | `true` |
| `enableHosting` | Enable Firebase Hosting | `false` |
| `firebaseFunctionsRegion` | Functions region | `europe-west1` |
| `firestoreRegion` | Firestore region | `eur3` |

## 📊 What Gets Created

### For Each Environment (dev, staging, prod):

#### 1. GCP/Firebase Project
```
Project ID: my-app-dev
Project Name: my-app-dev
Labels: environment=dev, managed-by=pulumi
```

#### 2. Enabled APIs
- firebase.googleapis.com
- firebasehosting.googleapis.com
- cloudfunctions.googleapis.com
- cloudbuild.googleapis.com
- identitytoolkit.googleapis.com (Auth)
- firestore.googleapis.com (Firestore)
- storage.googleapis.com (Storage)

#### 3. Registered Apps

**Android App:**
- Package: `com.mycompany.myapp.dev`
- Config file: `google-services.json` (base64 encoded)
- GitHub Secret: `GOOGLE_SERVICES_JSON_DEV`

**iOS App:**
- Bundle ID: `com.mycompany.myapp.dev`
- Config file: `GoogleService-Info.plist` (base64 encoded)
- GitHub Secret: `GOOGLE_SERVICES_PLIST_DEV`

#### 4. Service Account
```
Email: my-app-dev-cicd@my-app-dev.iam.gserviceaccount.com
Roles:
  - roles/firebase.admin
  - roles/firebaseauth.admin
  - roles/datastore.user
  - roles/cloudfunctions.admin
  - roles/storage.admin
  - roles/iam.serviceAccountUser
```

#### 5. Security Rules

**Firestore Rules:**
```javascript
rules_version = "2";
service cloud.firestore {
  match /databases/{database}/documents {
    // Default: Deny all
    match /{document=**} {
      allow read, write: if false;
    }

    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Public collections
    match /public/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

**Storage Rules:**
```javascript
rules_version = "2";
service firebase.storage {
  match /b/{bucket}/o {
    // Default: Deny all
    match /{allPaths=**} {
      allow read, write: if false;
    }

    // Users can read/write their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Public read
    match /public/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Shared Resources:

#### Android Signing Key
```
Keystore: keystore.jks (base64 encoded)
Key Alias: my-app-key
Validity: 10,000 days
Key Size: 2048 bits RSA
Passwords: Auto-generated (32 characters)
```

### GitHub Secrets Created:

**Per Environment (× 3):**
- `FIREBASE_PROJECT_ID_DEV/STAGING/PROD`
- `FIREBASE_SERVICE_ACCOUNT_DEV/STAGING/PROD`
- `GOOGLE_SERVICES_JSON_DEV/STAGING/PROD`
- `GOOGLE_SERVICES_PLIST_DEV/STAGING/PROD`

**Android (shared):**
- `ANDROID_KEYSTORE`
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

**Total: 16 secrets configured automatically!**

## 🔄 Common Operations

### Update Configuration

```bash
# Change a setting
pulumi config set firestoreRegion "nam5"

# Apply changes
pulumi up
```

### Add New Environment

```bash
# Update environments
pulumi config set environments '["dev","staging","prod","qa"]'

# Deploy
pulumi up
```

### View Outputs

```bash
# List all outputs
pulumi stack output

# Get specific output
pulumi stack output firebase_project_id_dev

# Get service account key (encrypted)
pulumi stack output service_account_key_dev --show-secrets
```

### Destroy Infrastructure

```bash
# Destroy everything (CAREFUL!)
pulumi destroy

# Note: Production projects are protected by default
# You'll need to manually confirm destruction
```

### Export State

```bash
# Export stack to JSON
pulumi stack export > stack-backup.json

# Import stack from JSON
pulumi stack import < stack-backup.json
```

## 🐛 Troubleshooting

### Issue: "gcloud: command not found"

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Login
gcloud auth login
gcloud auth application-default login
```

### Issue: "Firebase CLI not found"

```bash
npm install -g firebase-tools
firebase login
```

### Issue: "Insufficient permissions"

```bash
# Ensure you're logged in with correct account
gcloud auth list

# Set correct project
gcloud config set project YOUR_PROJECT_ID

# Ensure you have roles:
# - Project Creator
# - Firebase Admin
# - Service Account Admin
```

### Issue: "Pulumi state error"

```bash
# Refresh state
pulumi refresh

# If completely broken, export and reimport
pulumi stack export > backup.json
pulumi stack rm --force
pulumi stack init new-stack
pulumi stack import < backup.json
```

### Issue: "GitHub token invalid"

```bash
# Create new token with correct scopes:
# - repo (full control)
# - admin:repo_hook

# Update secret
pulumi config set githubToken --secret "ghp_NEW_TOKEN"
```

## 🎯 Best Practices

### 1. Use Separate Stacks for Different Projects

```bash
# Project 1
pulumi stack init project1-infra
pulumi config set projectBaseName "project1"
pulumi up

# Project 2
pulumi stack init project2-infra
pulumi config set projectBaseName "project2"
pulumi up
```

### 2. Version Control Your Stack Configuration

```bash
# Commit Pulumi.yaml and Pulumi.<stack>.yaml
git add Pulumi.yaml Pulumi.*.yaml
git commit -m "Add Pulumi configuration"
```

### 3. Use Pulumi Secrets for Sensitive Data

```bash
# Always use --secret for sensitive values
pulumi config set gcpBillingAccount --secret "xxx"
pulumi config set githubToken --secret "ghp_xxx"
```

### 4. Test in Dev First

```bash
# Set to only create dev environment initially
pulumi config set environments '["dev"]'
pulumi up

# Once verified, add others
pulumi config set environments '["dev","staging","prod"]'
pulumi up
```

### 5. Regular Backups

```bash
# Create weekly backups
pulumi stack export > backups/stack-$(date +%Y%m%d).json
```

## 📚 Additional Resources

- [Pulumi Documentation](https://www.pulumi.com/docs/)
- [Pulumi GCP Provider](https://www.pulumi.com/registry/packages/gcp/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google Cloud Documentation](https://cloud.google.com/docs)

## 🆘 Need Help?

1. Check [Troubleshooting](#troubleshooting) section
2. Review [Pulumi logs](#viewing-logs)
3. Open an issue on GitHub
4. Join Pulumi Community Slack

---

**Infrastructure as Code makes your setup reproducible, versioned, and auditable! 🚀**
