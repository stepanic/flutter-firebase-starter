import * as pulumi from "@pulumi/pulumi";
import { createFirebaseEnvironment } from "./firebase";
import { setupGitHubSecrets } from "./github";
import { generateAndroidSigningKey } from "./android";

// Get configuration
const config = new pulumi.Config();
const projectBaseName = config.require("projectBaseName");
const organization = config.require("organization");
const environments = config.requireObject<string[]>("environments");
const githubRepo = config.require("githubRepo");

// Optional GCP configuration
const gcpBillingAccount = config.get("gcpBillingAccount");
const gcpOrganizationId = config.get("gcpOrganizationId");

// Feature flags
const enableAuth = config.getBoolean("enableAuth") ?? true;
const enableFirestore = config.getBoolean("enableFirestore") ?? true;
const enableFunctions = config.getBoolean("enableFunctions") ?? true;
const enableStorage = config.getBoolean("enableStorage") ?? true;
const enableHosting = config.getBoolean("enableHosting") ?? false;

// App configuration
const androidPackageName = config.require("androidPackageName");
const iosBundleId = config.require("iosBundleId");

// Regions
const firebaseFunctionsRegion = config.get("firebaseFunctionsRegion") || "europe-west1";
const firestoreRegion = config.get("firestoreRegion") || "eur3";

// ============================================================================
// Create Firebase environments
// ============================================================================

interface FirebaseEnvironmentOutputs {
  projectId: pulumi.Output<string>;
  projectNumber: pulumi.Output<string>;
  webApiKey: pulumi.Output<string>;
  serviceAccountEmail: pulumi.Output<string>;
  serviceAccountKey: pulumi.Output<string>;
  googleServicesJson: pulumi.Output<string>;
  googleServicesPlist: pulumi.Output<string>;
}

const firebaseEnvironments: Record<string, FirebaseEnvironmentOutputs> = {};

for (const env of environments) {
  const projectName = `${projectBaseName}-${env}`;

  pulumi.log.info(`Creating Firebase environment: ${projectName}`);

  const environment = createFirebaseEnvironment({
    projectName,
    environment: env,
    billingAccount: gcpBillingAccount,
    organizationId: gcpOrganizationId,
    enableAuth,
    enableFirestore,
    enableFunctions,
    enableStorage,
    enableHosting,
    androidPackageName: `${androidPackageName}.${env}`,
    iosBundleId: `${iosBundleId}.${env}`,
    firestoreRegion,
    functionsRegion: firebaseFunctionsRegion,
  });

  firebaseEnvironments[env] = environment;
}

// ============================================================================
// Generate Android signing key (shared across environments)
// ============================================================================

const androidSigning = generateAndroidSigningKey({
  keyAlias: `${projectBaseName}-key`,
  organization: organization,
  commonName: projectBaseName,
});

// ============================================================================
// Setup GitHub secrets
// ============================================================================

const githubSecrets = setupGitHubSecrets({
  repository: githubRepo,
  firebaseEnvironments,
  androidSigning,
  environments,
});

// ============================================================================
// Export outputs
// ============================================================================

// Build exports dynamically
const firebaseOutputs: Record<string, any> = {};

// Firebase project IDs
for (const env of environments) {
  firebaseOutputs[`firebase_project_id_${env}`] = firebaseEnvironments[env].projectId;
  firebaseOutputs[`firebase_project_number_${env}`] = firebaseEnvironments[env].projectNumber;
  firebaseOutputs[`firebase_web_api_key_${env}`] = firebaseEnvironments[env].webApiKey;
}

// Service accounts
for (const env of environments) {
  firebaseOutputs[`service_account_email_${env}`] = firebaseEnvironments[env].serviceAccountEmail;
  firebaseOutputs[`service_account_key_${env}`] = pulumi.secret(firebaseEnvironments[env].serviceAccountKey);
}

// Configuration files (base64 encoded for GitHub secrets)
for (const env of environments) {
  firebaseOutputs[`google_services_json_${env}`] = pulumi.secret(firebaseEnvironments[env].googleServicesJson);
  firebaseOutputs[`google_services_plist_${env}`] = pulumi.secret(firebaseEnvironments[env].googleServicesPlist);
}

// Export all outputs using module.exports for proper Pulumi export
module.exports = {
  ...firebaseOutputs,
  // Android signing
  androidKeystore: pulumi.secret(androidSigning.keystoreBase64),
  androidKeystorePassword: pulumi.secret(androidSigning.keystorePassword),
  androidKeyPassword: pulumi.secret(androidSigning.keyPassword),
  androidKeyAlias: androidSigning.keyAlias,
  // GitHub secrets status
  githubSecretsConfigured: githubSecrets.secretsConfigured,
  // Summary
  summary: pulumi.interpolate`🎉 Firebase Infrastructure Created Successfully!

📦 Projects Created:
${environments.map(env => `   - ${projectBaseName}-${env}`).join('\n')}

🔥 Services Enabled:
   ${enableAuth ? '✅' : '❌'} Firebase Authentication
   ${enableFirestore ? '✅' : '❌'} Cloud Firestore
   ${enableFunctions ? '✅' : '❌'} Cloud Functions
   ${enableStorage ? '✅' : '❌'} Cloud Storage
   ${enableHosting ? '✅' : '❌'} Firebase Hosting

🔐 Security:
   ✅ Service accounts created
   ✅ API keys generated
   ✅ Android signing key generated
   ✅ GitHub secrets configured

📱 Apps Registered:
   ✅ Android apps (${environments.length} flavors)
   ✅ iOS apps (${environments.length} schemes)

🔗 GitHub Repository: ${githubRepo}

Next Steps:
1. Clone your Flutter project
2. Run: flutter pub get
3. Run: flutter run --flavor dev
4. Push to GitHub to trigger CI/CD!

🚀 You're ready to start building!`
};
