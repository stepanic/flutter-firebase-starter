#!/usr/bin/env node

/**
 * Pulumi CLI Wrapper
 *
 * This is a TypeScript CLI that wraps Pulumi operations with proper type safety.
 * Instead of fighting with bash and jq to set configuration, we use the Pulumi
 * Automation API to programmatically manage stacks.
 */

import * as pulumi from '@pulumi/pulumi';
import { LocalWorkspace, Stack } from '@pulumi/pulumi/automation';
import * as path from 'path';
import * as fs from 'fs';

interface DeployOptions {
  projectBaseName: string;
  organization: string;
  environments: string[];
  githubRepo: string;
  androidPackageName: string;
  iosBundleId: string;
  gcpBillingAccount?: string;
  gcpOrganizationId?: string;
  githubToken?: string;
  firestoreRegion?: string;
  firebaseFunctionsRegion?: string;
  enableAuth?: boolean;
  enableFirestore?: boolean;
  enableFunctions?: boolean;
  enableStorage?: boolean;
  enableHosting?: boolean;
}

async function configureStack(stack: Stack, options: DeployOptions): Promise<void> {
  console.log('⚙️  Configuring stack...');

  // Required configurations
  await stack.setConfig('projectBaseName', { value: options.projectBaseName });
  await stack.setConfig('organization', { value: options.organization });
  await stack.setConfig('environments', { value: JSON.stringify(options.environments) });
  await stack.setConfig('githubRepo', { value: options.githubRepo });
  await stack.setConfig('androidPackageName', { value: options.androidPackageName });
  await stack.setConfig('iosBundleId', { value: options.iosBundleId });

  // Optional configurations
  if (options.gcpBillingAccount) {
    await stack.setConfig('gcpBillingAccount', { value: options.gcpBillingAccount, secret: true });
  }

  if (options.gcpOrganizationId) {
    await stack.setConfig('gcpOrganizationId', { value: options.gcpOrganizationId });
  }

  if (options.githubToken) {
    await stack.setConfig('githubToken', { value: options.githubToken, secret: true });
  }

  // Regional settings
  await stack.setConfig('firestoreRegion', { value: options.firestoreRegion || 'eur3' });
  await stack.setConfig('firebaseFunctionsRegion', { value: options.firebaseFunctionsRegion || 'europe-west1' });

  // Feature flags
  await stack.setConfig('enableAuth', { value: String(options.enableAuth !== false) });
  await stack.setConfig('enableFirestore', { value: String(options.enableFirestore !== false) });
  await stack.setConfig('enableFunctions', { value: String(options.enableFunctions !== false) });
  await stack.setConfig('enableStorage', { value: String(options.enableStorage !== false) });
  await stack.setConfig('enableHosting', { value: String(options.enableHosting || false) });

  console.log('✅ Stack configured');
}

async function deploy(options: DeployOptions): Promise<void> {
  const baseStackName = `${options.projectBaseName}-infra`;
  const workDir = path.join(__dirname);

  console.log(`\n🚀 Starting deployment for stack: ${baseStackName}\n`);
  console.log('🔍 Detecting Pulumi backend...');

  try {
    // Get current Pulumi user to construct proper stack name
    const { execSync } = require('child_process');
    let pulumiUser = '';
    try {
      pulumiUser = execSync('pulumi whoami', { encoding: 'utf-8' }).trim();
      console.log(`   └─ Logged in as: ${pulumiUser}`);
    } catch (err) {
      console.error('❌ Not logged into Pulumi. Please run: pulumi login');
      process.exit(1);
    }

    // Construct full stack name with user/org
    const stackName = `${pulumiUser}/${baseStackName}`;
    console.log(`   └─ Full stack name: ${stackName}\n`);

    // Create or select stack using the working directory (where Pulumi.yaml exists)
    const stack = await LocalWorkspace.createOrSelectStack({
      stackName,
      workDir,
    });

    console.log(`✅ Stack ready: ${stackName}`);

    // Configure stack
    await configureStack(stack, options);

    // Show current configuration
    console.log('\n📋 Stack Configuration:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    const config = await stack.getAllConfig();
    for (const [key, value] of Object.entries(config)) {
      if (value.secret) {
        console.log(`  🔐 ${key}: [secret]`);
      } else {
        console.log(`  ⚙️  ${key}: ${value.value}`);
      }
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Show what will be created
    console.log('🏗️  Infrastructure to be provisioned:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    for (const env of options.environments) {
      console.log(`\n  📦 Environment: ${env.toUpperCase()}`);
      console.log(`     └─ 🔥 Firebase Project: ${options.projectBaseName}-${env}`);
      console.log(`     └─ 🌍 GCP Project ID: ${options.projectBaseName}-${env}`);
      console.log(`     └─ 🔐 Firebase Authentication`);
      if (options.enableFirestore !== false) {
        console.log(`     └─ 📊 Cloud Firestore (region: ${options.firestoreRegion})`);
      }
      if (options.enableFunctions !== false) {
        console.log(`     └─ ⚡ Cloud Functions (region: ${options.firebaseFunctionsRegion})`);
      }
      if (options.enableStorage !== false) {
        console.log(`     └─ 📁 Cloud Storage`);
      }
      console.log(`     └─ 📱 Android App: ${options.androidPackageName}.${env}`);
      console.log(`     └─ 🍎 iOS App: ${options.iosBundleId}.${env}`);
    }
    console.log('\n  🔗 GitHub Integration:');
    console.log(`     └─ 📦 Repository: ${options.githubRepo}`);
    console.log(`     └─ 🔑 Secrets: Firebase config, Service accounts, Android keys`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Confirm deployment
    console.log('⚠️  This will create real GCP resources and may incur costs.');
    console.log('⏳ Starting deployment in 3 seconds... (Ctrl+C to cancel)\n');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Deploy
    console.log('🚀 STARTING DEPLOYMENT');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('📝 This may take 5-10 minutes. Live progress below:\n');

    const upResult = await stack.up({
      onOutput: (msg) => process.stdout.write(msg),
    });

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ DEPLOYMENT COMPLETE!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('📊 Resource Changes:');
    const changes = upResult.summary.resourceChanges || {};
    if (changes.create) console.log(`  ➕ Created: ${changes.create} resources`);
    if (changes.update) console.log(`  🔄 Updated: ${changes.update} resources`);
    if (changes.delete) console.log(`  ➖ Deleted: ${changes.delete} resources`);
    if (changes.same) console.log(`  ⏸️  Unchanged: ${changes.same} resources`);

    // Export outputs
    console.log('\n💾 Exporting outputs...');
    const outputs = await stack.outputs();
    const outputFile = path.join(workDir, '../../firebase-infrastructure-outputs.json');

    const outputData: Record<string, any> = {};
    for (const [key, value] of Object.entries(outputs)) {
      outputData[key] = value.value;
    }

    fs.writeFileSync(outputFile, JSON.stringify(outputData, null, 2));
    console.log(`   └─ 📄 Saved to: ${outputFile}`);

    // Print detailed summary
    console.log('\n🔥 Firebase Projects Created:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    for (const env of options.environments) {
      const projectId = `${options.projectBaseName}-${env}`;
      console.log(`\n  ✅ ${env.toUpperCase()} Environment`);
      console.log(`     └─ 🆔 Project ID: ${projectId}`);
      console.log(`     └─ 🌐 Console: https://console.firebase.google.com/project/${projectId}`);
      console.log(`     └─ 📱 Android: ${options.androidPackageName}.${env}`);
      console.log(`     └─ 🍎 iOS: ${options.iosBundleId}.${env}`);
    }

    console.log('\n🔗 GitHub Secrets Configured:');
    console.log(`   └─ 📦 Repository: https://github.com/${options.githubRepo}`);
    console.log(`   └─ 🔑 Secrets: https://github.com/${options.githubRepo}/settings/secrets/actions`);

    console.log('\n📋 Next Steps:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('  1️⃣  Review outputs: cat firebase-infrastructure-outputs.json | jq');
    console.log('  2️⃣  Copy Firebase config files to your Flutter project');
    console.log('  3️⃣  Test your Flutter app: flutter run --flavor dev');
    console.log('  4️⃣  Push to GitHub to trigger CI/CD workflows');

    console.log('\n🎉 Infrastructure deployment completed successfully!\n');

  } catch (error) {
    console.error('\n❌ Deployment failed:');
    console.error(error);
    process.exit(1);
  }
}

async function destroy(stackName: string): Promise<void> {
  const workDir = path.join(__dirname);

  console.log(`\n🗑️  Destroying stack: ${stackName}\n`);

  try {
    const stack = await LocalWorkspace.selectStack({
      stackName,
      workDir,
    });

    console.log('⚠️  This will destroy all infrastructure. Continue? (waiting 5 seconds...)');
    await new Promise(resolve => setTimeout(resolve, 5000));

    await stack.destroy({
      onOutput: (msg) => process.stdout.write(msg),
    });

    console.log('\n✅ Stack destroyed');

  } catch (error) {
    console.error('\n❌ Destroy failed:');
    console.error(error);
    process.exit(1);
  }
}

// CLI interface
const command = process.argv[2];

if (command === 'deploy') {
  // Read configuration from stdin or environment
  const configFile = process.argv[3];

  if (!configFile) {
    console.error('Usage: cli.ts deploy <config-file>');
    process.exit(1);
  }

  const config = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
  deploy(config).catch(err => {
    console.error(err);
    process.exit(1);
  });

} else if (command === 'destroy') {
  const stackName = process.argv[3];

  if (!stackName) {
    console.error('Usage: cli.ts destroy <stack-name>');
    process.exit(1);
  }

  destroy(stackName).catch(err => {
    console.error(err);
    process.exit(1);
  });

} else {
  console.error('Usage:');
  console.error('  cli.ts deploy <config-file>');
  console.error('  cli.ts destroy <stack-name>');
  process.exit(1);
}
