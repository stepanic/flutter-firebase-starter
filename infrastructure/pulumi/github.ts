import * as github from "@pulumi/github";
import * as pulumi from "@pulumi/pulumi";

export interface GitHubSecretsConfig {
  repository: string;
  firebaseEnvironments: Record<string, {
    projectId: pulumi.Output<string>;
    serviceAccountKey: pulumi.Output<string>;
    googleServicesJson: pulumi.Output<string>;
    googleServicesPlist: pulumi.Output<string>;
  }>;
  androidSigning: {
    keystoreBase64: pulumi.Output<string>;
    keystorePassword: pulumi.Output<string>;
    keyPassword: pulumi.Output<string>;
    keyAlias: string;
  };
  environments: string[];
}

export interface GitHubSecretsOutputs {
  secretsConfigured: pulumi.Output<boolean>;
}

export function setupGitHubSecrets(config: GitHubSecretsConfig): GitHubSecretsOutputs {
  const { repository, firebaseEnvironments, androidSigning, environments } = config;

  // Parse repository (owner/repo)
  const [owner, repo] = repository.split("/");

  // ============================================================================
  // Create GitHub secrets for each Firebase environment
  // ============================================================================

  const createdSecrets: github.ActionsSecret[] = [];

  for (const env of environments) {
    const envData = firebaseEnvironments[env];

    // Firebase Project ID
    const projectIdSecret = new github.ActionsSecret(
      `secret-firebase-project-id-${env}`,
      {
        repository: repo,
        secretName: `FIREBASE_PROJECT_ID_${env.toUpperCase()}`,
        plaintextValue: envData.projectId,
      }
    );
    createdSecrets.push(projectIdSecret);

    // Service Account Key (base64 encoded)
    const serviceAccountSecret = new github.ActionsSecret(
      `secret-firebase-sa-key-${env}`,
      {
        repository: repo,
        secretName: `FIREBASE_SERVICE_ACCOUNT_${env.toUpperCase()}`,
        plaintextValue: envData.serviceAccountKey,
      }
    );
    createdSecrets.push(serviceAccountSecret);

    // Google Services JSON (base64 encoded)
    const googleServicesJsonSecret = new github.ActionsSecret(
      `secret-google-services-json-${env}`,
      {
        repository: repo,
        secretName: `GOOGLE_SERVICES_JSON_${env.toUpperCase()}`,
        plaintextValue: envData.googleServicesJson,
      }
    );
    createdSecrets.push(googleServicesJsonSecret);

    // Google Services PLIST (base64 encoded)
    const googleServicesPlistSecret = new github.ActionsSecret(
      `secret-google-services-plist-${env}`,
      {
        repository: repo,
        secretName: `GOOGLE_SERVICES_PLIST_${env.toUpperCase()}`,
        plaintextValue: envData.googleServicesPlist,
      }
    );
    createdSecrets.push(googleServicesPlistSecret);
  }

  // ============================================================================
  // Create Android signing secrets
  // ============================================================================

  const androidKeystoreSecret = new github.ActionsSecret(
    "secret-android-keystore",
    {
      repository: repo,
      secretName: "ANDROID_KEYSTORE",
      plaintextValue: androidSigning.keystoreBase64,
    }
  );
  createdSecrets.push(androidKeystoreSecret);

  const keystorePasswordSecret = new github.ActionsSecret(
    "secret-keystore-password",
    {
      repository: repo,
      secretName: "KEYSTORE_PASSWORD",
      plaintextValue: androidSigning.keystorePassword,
    }
  );
  createdSecrets.push(keystorePasswordSecret);

  const keyPasswordSecret = new github.ActionsSecret("secret-key-password", {
    repository: repo,
    secretName: "KEY_PASSWORD",
    plaintextValue: androidSigning.keyPassword,
  });
  createdSecrets.push(keyPasswordSecret);

  const keyAliasSecret = new github.ActionsSecret("secret-key-alias", {
    repository: repo,
    secretName: "KEY_ALIAS",
    plaintextValue: androidSigning.keyAlias,
  });
  createdSecrets.push(keyAliasSecret);

  // ============================================================================
  // Return outputs
  // ============================================================================

  return {
    secretsConfigured: pulumi
      .all(createdSecrets.map((s) => s.id))
      .apply((ids) => ids.length > 0),
  };
}
