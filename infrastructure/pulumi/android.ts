import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";
import * as command from "@pulumi/command";

export interface AndroidSigningKeyConfig {
  keyAlias: string;
  organization: string;
  commonName: string;
  validity?: number; // days, default 10000
  keySize?: number; // default 2048
}

export interface AndroidSigningKeyOutputs {
  keystoreBase64: pulumi.Output<string>;
  keystorePassword: pulumi.Output<string>;
  keyPassword: pulumi.Output<string>;
  keyAlias: string;
}

export function generateAndroidSigningKey(
  config: AndroidSigningKeyConfig
): AndroidSigningKeyOutputs {
  const { keyAlias, organization, commonName, validity = 10000, keySize = 2048 } = config;

  // ============================================================================
  // Generate random passwords
  // ============================================================================

  const keystorePassword = new random.RandomPassword(
    `${keyAlias}-keystore-password`,
    {
      length: 32,
      special: true,
      overrideSpecial: "!@#$%^&*()_+-=[]{}|;:,.<>?",
    }
  );

  const keyPassword = new random.RandomPassword(`${keyAlias}-key-password`, {
    length: 32,
    special: true,
    overrideSpecial: "!@#$%^&*()_+-=[]{}|;:,.<>?",
  });

  // ============================================================================
  // Generate keystore using keytool
  // ============================================================================

  const keystoreFilePath = `/tmp/${keyAlias}.jks`;

  const generateKeystore = new command.local.Command(
    `${keyAlias}-generate-keystore`,
    {
      create: pulumi.interpolate`keytool -genkey -v \
        -keystore ${keystoreFilePath} \
        -alias ${keyAlias} \
        -keyalg RSA \
        -keysize ${keySize} \
        -validity ${validity} \
        -storepass "${keystorePassword.result}" \
        -keypass "${keyPassword.result}" \
        -dname "CN=${commonName}, OU=${organization}, O=${organization}, L=Unknown, ST=Unknown, C=US" \
        && echo "Keystore generated successfully"`,
      triggers: [keystorePassword.result, keyPassword.result],
    }
  );

  // ============================================================================
  // Convert keystore to base64 for GitHub Secrets
  // ============================================================================

  const keystoreBase64 = new command.local.Command(
    `${keyAlias}-keystore-base64`,
    {
      create: pulumi.interpolate`cat ${keystoreFilePath} | base64`,
    },
    {
      dependsOn: [generateKeystore],
    }
  );

  // ============================================================================
  // Clean up (optional - comment out if you want to keep local keystore)
  // ============================================================================

  const cleanup = new command.local.Command(
    `${keyAlias}-cleanup`,
    {
      create: pulumi.interpolate`rm -f ${keystoreFilePath} && echo "Cleanup complete"`,
    },
    {
      dependsOn: [keystoreBase64],
    }
  );

  // ============================================================================
  // Return outputs
  // ============================================================================

  return {
    keystoreBase64: keystoreBase64.stdout.apply((b64) => b64.trim()),
    keystorePassword: keystorePassword.result,
    keyPassword: keyPassword.result,
    keyAlias: keyAlias,
  };
}
