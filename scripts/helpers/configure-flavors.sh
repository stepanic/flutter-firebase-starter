#!/bin/bash

# Configure Android and iOS flavors for Flutter project

PROJECT_NAME="$1"
ORGANIZATION="$2"

if [[ -z "$PROJECT_NAME" ]] || [[ -z "$ORGANIZATION" ]]; then
    echo "Usage: configure-flavors.sh <project_name> <organization>"
    exit 1
fi

echo "Configuring flavors for $PROJECT_NAME..."

# ============================================================================
# Android Configuration
# ============================================================================

# Create flavor directories
mkdir -p android/app/src/dev/res/values
mkdir -p android/app/src/staging/res/values
mkdir -p android/app/src/prod/res/values

# Dev strings
cat > android/app/src/dev/res/values/strings.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$PROJECT_NAME DEV</string>
</resources>
EOF

# Staging strings
cat > android/app/src/staging/res/values/strings.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$PROJECT_NAME STAGING</string>
</resources>
EOF

# Prod strings
cat > android/app/src/prod/res/values/strings.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$PROJECT_NAME</string>
</resources>
EOF

# Update build.gradle
cat > android/app/build.gradle << EOF
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

android {
    namespace "$ORGANIZATION.$PROJECT_NAME"
    compileSdk flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "$ORGANIZATION.$PROJECT_NAME"
        minSdk flutter.minSdkVersion
        targetSdk flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    signingConfigs {
        release {
            if (System.getenv("CI")) {
                storeFile file("keystore.jks")
                storePassword System.getenv("KEYSTORE_PASSWORD")
                keyAlias System.getenv("KEY_ALIAS")
                keyPassword System.getenv("KEY_PASSWORD")
            }
        }
    }

    flavorDimensions "environment"
    productFlavors {
        dev {
            dimension "environment"
            applicationIdSuffix ".dev"
            versionNameSuffix "-dev"
        }
        staging {
            dimension "environment"
            applicationIdSuffix ".staging"
            versionNameSuffix "-staging"
        }
        prod {
            dimension "environment"
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        debug {
            applicationIdSuffix ".debug"
        }
    }
}

flutter {
    source '../..'
}

dependencies {}
EOF

echo "✅ Android flavors configured"

# ============================================================================
# iOS Configuration
# ============================================================================

mkdir -p ios/Runner/Configurations

# Dev configuration
cat > ios/Runner/Configurations/Dev.xcconfig << EOF
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.dev.xcconfig"
#include "Generated.xcconfig"

FLUTTER_TARGET=lib/main_dev.dart
PRODUCT_BUNDLE_IDENTIFIER=$ORGANIZATION.$PROJECT_NAME.dev
PRODUCT_NAME=$PROJECT_NAME DEV
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-Dev
EOF

# Staging configuration
cat > ios/Runner/Configurations/Staging.xcconfig << EOF
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.staging.xcconfig"
#include "Generated.xcconfig"

FLUTTER_TARGET=lib/main_staging.dart
PRODUCT_BUNDLE_IDENTIFIER=$ORGANIZATION.$PROJECT_NAME.staging
PRODUCT_NAME=$PROJECT_NAME STAGING
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-Staging
EOF

# Prod configuration
cat > ios/Runner/Configurations/Prod.xcconfig << EOF
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.prod.xcconfig"
#include "Generated.xcconfig"

FLUTTER_TARGET=lib/main_prod.dart
PRODUCT_BUNDLE_IDENTIFIER=$ORGANIZATION.$PROJECT_NAME
PRODUCT_NAME=$PROJECT_NAME
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon
EOF

echo "✅ iOS schemes configured"
echo "⚠️  Note: You may need to configure schemes in Xcode manually"

# ============================================================================
# Dart Configuration Files
# ============================================================================

# Flavor config
cat > lib/config/flavor_config.dart << 'EODART'
enum Flavor {
  dev,
  staging,
  prod,
}

class FlavorConfig {
  final Flavor flavor;
  final String name;
  final String apiBaseUrl;
  final bool enableLogging;
  final bool enableAnalytics;

  FlavorConfig({
    required this.flavor,
    required this.name,
    required this.apiBaseUrl,
    required this.enableLogging,
    required this.enableAnalytics,
  });

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    assert(_instance != null, 'FlavorConfig not initialized');
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static void initialize({required Flavor flavor}) {
    _instance = FlavorConfig._create(flavor);
  }

  factory FlavorConfig._create(Flavor flavor) {
    switch (flavor) {
      case Flavor.dev:
        return FlavorConfig(
          flavor: flavor,
          name: 'Development',
          apiBaseUrl: 'https://dev-api.example.com',
          enableLogging: true,
          enableAnalytics: false,
        );
      case Flavor.staging:
        return FlavorConfig(
          flavor: flavor,
          name: 'Staging',
          apiBaseUrl: 'https://staging-api.example.com',
          enableLogging: true,
          enableAnalytics: true,
        );
      case Flavor.prod:
        return FlavorConfig(
          flavor: flavor,
          name: 'Production',
          apiBaseUrl: 'https://api.example.com',
          enableLogging: false,
          enableAnalytics: true,
        );
    }
  }

  bool get isDev => flavor == Flavor.dev;
  bool get isStaging => flavor == Flavor.staging;
  bool get isProd => flavor == Flavor.prod;
}
EODART

# Main entry points
cat > lib/main_dev.dart << 'EODART'
import 'package:flutter/material.dart';
import 'config/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(flavor: Flavor.dev);
  app.main();
}
EODART

cat > lib/main_staging.dart << 'EODART'
import 'package:flutter/material.dart';
import 'config/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(flavor: Flavor.staging);
  app.main();
}
EODART

cat > lib/main_prod.dart << 'EODART'
import 'package:flutter/material.dart';
import 'config/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(flavor: Flavor.prod);
  app.main();
}
EODART

echo "✅ Dart configuration files created"
echo "✅ Flavor configuration complete!"
