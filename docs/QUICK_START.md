# 🚀 Quick Start Guide

Get a production-ready Flutter + Firebase project running in **15 minutes**!

## 📋 Prerequisites Checklist

Before starting, ensure you have:

```bash
# Check Flutter
flutter --version
# Need: Flutter 3.24.0+

# Check Dart
dart --version
# Need: Dart 3.5.0+

# Check Node.js
node --version
# Need: Node.js 20+

# Check Git
git --version

# Check GitHub CLI
gh --version
# Install: brew install gh

# Check Google Cloud SDK
gcloud --version
# Install: brew install --cask google-cloud-sdk

# Check Firebase CLI
firebase --version
# Install: npm install -g firebase-tools

# Check Pulumi (optional, but recommended)
pulumi version
# Install: curl -fsSL https://get.pulumi.com | sh
```

**Missing something?** See [Installation Guide](./INSTALLATION.md)

## 🎯 Option 1: Fully Automated Setup (Recommended)

This uses Infrastructure as Code (Pulumi) to automate **everything**.

### Step 1: Login to Services

```bash
# Login to Google Cloud
gcloud auth login
gcloud auth application-default login

# Login to Firebase
firebase login

# Login to GitHub
gh auth login

# Login to Pulumi
pulumi login
```

### Step 2: Run Initialization Script

```bash
# Clone this starter toolkit
git clone https://github.com/yourusername/flutter-firebase-starter.git
cd flutter-firebase-starter

# Run the magic script
./scripts/init-flutter-app.sh
```

### Step 3: Follow Interactive Prompts

The script will ask you:

```
🚀 FLUTTER FIREBASE STARTER

Step 1: Checking Prerequisites
✅ Flutter installed: 3.24.0
✅ Dart installed
✅ Git installed
✅ Node.js: v20.11.0
✅ npm: 10.2.4
✅ GitHub CLI installed
✅ Google Cloud SDK installed
✅ Firebase CLI installed
✅ Pulumi installed

Use Infrastructure as Code (Pulumi) for Firebase setup? (y/n)
> y

Step 2: Project Configuration

Enter project name (lowercase, underscores only):
> my_awesome_app

Enter organization (reverse domain, e.g., com.mycompany):
> com.mycompany

Enter project description:
> My awesome Flutter app with Firebase

Enter GitHub repository (username/repo-name):
> johndoe/my-awesome-app

Firebase projects will be named: my-awesome-app-dev, my-awesome-app-staging, my-awesome-app-prod

Enter GCP Billing Account ID (optional, press Enter to skip):
> 01234567-89ABCD-EF0123

Configuration Summary:
  Project Name:      my_awesome_app
  Organization:      com.mycompany
  Description:       My awesome Flutter app with Firebase
  GitHub Repo:       johndoe/my-awesome-app
  Firebase Projects: my-awesome-app-{dev,staging,prod}
  Use IaC:           true

Continue with this configuration? (y/n)
> y
```

### Step 4: Wait for Magic to Happen ✨

The script will:

1. ✅ Create Flutter project (1 min)
2. ✅ Setup project structure (30 sec)
3. ✅ Configure Android & iOS flavors (1 min)
4. ✅ Create 3 Firebase projects (2-3 min)
5. ✅ Enable all Firebase services (1-2 min)
6. ✅ Register Android & iOS apps (1 min)
7. ✅ Download config files (30 sec)
8. ✅ Generate Android signing keys (30 sec)
9. ✅ Configure ALL GitHub secrets (1 min)
10. ✅ Create GitHub repository (30 sec)
11. ✅ Initial commit and push (30 sec)

**Total time: 10-15 minutes**

### Step 5: Verify Setup

```bash
# Go to your new project
cd my_awesome_app

# Install dependencies
flutter pub get

# Run in dev environment
flutter run --flavor dev -t lib/main_dev.dart

# You should see the app with a colored banner showing "Development" environment!
```

### Step 6: Check GitHub Actions

```bash
# Open GitHub Actions in browser
gh repo view --web

# Navigate to "Actions" tab
# You should see CI/CD workflows ready to run!
```

**🎉 Done! You now have:**
- ✅ Flutter app with 3 environments
- ✅ 3 Firebase projects fully configured
- ✅ All GitHub secrets set up
- ✅ CI/CD ready to deploy
- ✅ Android signing configured
- ✅ iOS schemes configured

**Time to start coding!** 🚀

---

## 🎯 Option 2: Semi-Automated Setup

If you prefer more control or don't want to use IaC.

### Step 1: Create Flutter Project

```bash
# Run initialization script without IaC
./scripts/init-flutter-app.sh

# When asked: "Use Infrastructure as Code (Pulumi)?"
# Answer: n
```

### Step 2: Manual Firebase Setup

Follow the instructions in `FIREBASE_SETUP_INSTRUCTIONS.md` that was generated:

1. **Create 3 Firebase projects**
   - Go to https://console.firebase.google.com/
   - Create: `my-app-dev`, `my-app-staging`, `my-app-prod`

2. **Enable services** (per project)
   - Firebase Authentication
   - Cloud Firestore
   - Cloud Functions
   - Cloud Storage

3. **Register apps** (per project)
   - Android app with package name
   - iOS app with bundle ID

4. **Download configs**
   - `google-services.json` → `android/app/src/{env}/`
   - `GoogleService-Info.plist` → `ios/Runner/{env}/`

**Time: ~2-3 hours**

### Step 3: Setup GitHub Secrets

```bash
# Run the secrets setup script
./scripts/setup-github-secrets.sh
```

This will help you:
- Base64 encode Firebase configs
- Generate Android signing keys
- Create all GitHub secrets

**Time: ~30-60 minutes**

---

## 🧪 Verify Your Setup

After setup (either option), run these tests:

### 1. Check Flutter App

```bash
# Analyze code
flutter analyze
# Should pass with no issues

# Run tests
flutter test
# Should pass (even if just example tests)

# Format code
dart format .
# Should complete successfully
```

### 2. Test Dev Environment

```bash
# Run on Android
flutter run --flavor dev -t lib/main_dev.dart

# Run on iOS (Mac only)
flutter run --flavor dev -t lib/main_dev.dart

# Run on Web
flutter run -t lib/main_dev.dart -d chrome
```

**Expected:** App launches with "Development" banner

### 3. Test Building

```bash
# Build Android APK (dev)
flutter build apk --flavor dev -t lib/main_dev.dart

# Build Android App Bundle (prod)
flutter build appbundle --flavor prod -t lib/main_prod.dart --release

# Build iOS (Mac only)
flutter build ios --flavor dev -t lib/main_dev.dart
```

**Expected:** Builds complete successfully

### 4. Check Firebase Connection

```bash
# Run FlutterFire configure
flutterfire configure

# This should show your 3 projects:
# - my-app-dev
# - my-app-staging
# - my-app-prod
```

### 5. Test CI/CD

```bash
# Create a test commit
echo "# Test" >> README.md
git add README.md
git commit -m "test: Trigger CI/CD"
git push

# Check GitHub Actions
gh run list
# Should show workflow running

# Watch live
gh run watch
```

**Expected:** CI/CD passes successfully

---

## 🎯 Next Steps

Now that your project is set up:

### 1. Customize Your App

```bash
# Edit main app file
code lib/main.dart

# Create your first feature
mkdir lib/features/auth
code lib/features/auth/login_screen.dart

# Add dependencies
flutter pub add firebase_auth
flutter pub add cloud_firestore
```

### 2. Setup Firebase Features

```bash
# Run FlutterFire configure for each environment
flutterfire configure \
  --project=my-app-dev \
  --out=lib/firebase_options_dev.dart \
  --ios-bundle-id=com.mycompany.myapp.dev \
  --android-package-name=com.mycompany.myapp.dev

# Repeat for staging and prod
```

### 3. Add More Dependencies

```bash
# State management
flutter pub add riverpod
# or: flutter pub add bloc
# or: flutter pub add provider

# Navigation
flutter pub add go_router

# HTTP client
flutter pub add dio

# Local storage
flutter pub add shared_preferences

# JSON serialization
flutter pub add json_annotation
flutter pub add --dev json_serializable
flutter pub add --dev build_runner
```

### 4. Create Your First Feature

Example: Authentication screen

```dart
// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Navigate to home
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5. Deploy to Stores

```bash
# Test release build
flutter build appbundle --flavor prod -t lib/main_prod.dart --release

# Create release tag (triggers CI/CD)
git tag v1.0.0-prod
git push origin v1.0.0-prod

# Watch deployment
gh run list
gh run watch
```

---

## 🆘 Troubleshooting

### Issue: Script fails at prerequisites check

**Solution:**
```bash
# Install missing tools
brew install flutter
brew install node@20
brew install gh
brew install --cask google-cloud-sdk
npm install -g firebase-tools
curl -fsSL https://get.pulumi.com | sh
```

### Issue: "Firebase project already exists"

**Solution:**
```bash
# Use different project name
# Or delete existing projects in Firebase console
```

### Issue: "GitHub repository already exists"

**Solution:**
```bash
# Use different repository name
# Or delete existing repository: gh repo delete username/repo-name
```

### Issue: "Insufficient GCP permissions"

**Solution:**
```bash
# Ensure your GCP account has these roles:
# - Project Creator
# - Firebase Admin
# - Service Account Admin

# Check current account
gcloud auth list

# Switch account if needed
gcloud config set account user@example.com
```

### Issue: Pulumi fails to create resources

**Solution:**
```bash
# Refresh Pulumi state
pulumi refresh

# Check Pulumi logs
pulumi logs

# If stuck, destroy and retry
pulumi destroy
pulumi up
```

### Issue: CI/CD workflow fails

**Solution:**
```bash
# Check if all secrets are set
gh secret list

# Verify Firebase configs
cat android/app/src/dev/google-services.json
cat ios/Runner/dev/GoogleService-Info.plist

# Check workflow logs
gh run view --log
```

---

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Pulumi Documentation](https://www.pulumi.com/docs/)

---

## 🎊 Success!

If you've made it here, you now have:
- ✅ Production-ready Flutter project
- ✅ 3 Firebase environments
- ✅ Complete CI/CD pipeline
- ✅ All secrets configured
- ✅ Multi-platform support

**Time to build something amazing!** 🚀

---

**Questions? Issues?**
- Open an issue: https://github.com/yourusername/flutter-firebase-starter/issues
- Check FAQ: [FAQ.md](./FAQ.md)
- Join Discord: [Link]
