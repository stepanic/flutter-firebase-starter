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
  const stackName = `${options.projectBaseName}-infra`;
  const projectName = 'firebase-infrastructure';
  const workDir = path.join(__dirname);

  console.log(`\n🚀 Starting deployment for stack: ${stackName}\n`);

  try {
    // Create or select stack
    const stack = await LocalWorkspace.createOrSelectStack({
      stackName,
      projectName,
      workDir,
    });

    console.log(`✅ Stack ready: ${stackName}`);

    // Configure stack
    await configureStack(stack, options);

    // Install dependencies
    console.log('\n📦 Installing dependencies...');
    await stack.workspace.installPluginDeps();

    // Show current configuration
    console.log('\n📋 Current configuration:');
    const config = await stack.getAllConfig();
    for (const [key, value] of Object.entries(config)) {
      if (value.secret) {
        console.log(`  ${key}: [secret]`);
      } else {
        console.log(`  ${key}: ${value.value}`);
      }
    }

    // Confirm deployment
    console.log('\n⚠️  Review the configuration above before proceeding');
    console.log('Starting deployment in 3 seconds... (Ctrl+C to cancel)\n');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Deploy
    console.log('▶️  Deploying Firebase infrastructure (this may take 5-10 minutes)...\n');

    const upResult = await stack.up({
      onOutput: (msg) => process.stdout.write(msg),
    });

    console.log('\n✅ Deployment complete!');
    console.log(`\n📊 Summary:`);
    console.log(`  Resources created: ${upResult.summary.resourceChanges?.create || 0}`);
    console.log(`  Resources updated: ${upResult.summary.resourceChanges?.update || 0}`);

    // Export outputs
    const outputs = await stack.outputs();
    const outputFile = path.join(workDir, '../../firebase-infrastructure-outputs.json');

    const outputData: Record<string, any> = {};
    for (const [key, value] of Object.entries(outputs)) {
      outputData[key] = value.value;
    }

    fs.writeFileSync(outputFile, JSON.stringify(outputData, null, 2));
    console.log(`\n💾 Outputs saved to: ${outputFile}`);

    // Print Firebase projects created
    console.log('\n🔥 Firebase projects created:');
    for (const env of options.environments) {
      console.log(`  ✅ ${options.projectBaseName}-${env}`);
    }

    console.log('\n🎉 All done!\n');

  } catch (error) {
    console.error('\n❌ Deployment failed:');
    console.error(error);
    process.exit(1);
  }
}

async function destroy(stackName: string): Promise<void> {
  const projectName = 'firebase-infrastructure';
  const workDir = path.join(__dirname);

  console.log(`\n🗑️  Destroying stack: ${stackName}\n`);

  try {
    const stack = await LocalWorkspace.selectStack({
      stackName,
      projectName,
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
