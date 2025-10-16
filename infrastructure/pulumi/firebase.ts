import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import * as command from "@pulumi/command";

export interface FirebaseEnvironmentConfig {
  projectName: string;
  environment: string;
  billingAccount?: string;
  organizationId?: string;
  enableAuth: boolean;
  enableFirestore: boolean;
  enableFunctions: boolean;
  enableStorage: boolean;
  enableHosting: boolean;
  androidPackageName: string;
  iosBundleId: string;
  firestoreRegion: string;
  functionsRegion: string;
}

export interface FirebaseEnvironmentOutputs {
  projectId: pulumi.Output<string>;
  projectNumber: pulumi.Output<string>;
  webApiKey: pulumi.Output<string>;
  serviceAccountEmail: pulumi.Output<string>;
  serviceAccountKey: pulumi.Output<string>;
  googleServicesJson: pulumi.Output<string>;
  googleServicesPlist: pulumi.Output<string>;
}

export function createFirebaseEnvironment(
  config: FirebaseEnvironmentConfig
): FirebaseEnvironmentOutputs {
  const {
    projectName,
    environment,
    billingAccount,
    organizationId,
    enableAuth,
    enableFirestore,
    enableFunctions,
    enableStorage,
    enableHosting,
    androidPackageName,
    iosBundleId,
    firestoreRegion,
    functionsRegion,
  } = config;

  // ============================================================================
  // Create GCP Project
  // ============================================================================

  const project = new gcp.organizations.Project(
    `${projectName}-project`,
    {
      projectId: projectName,
      name: projectName,
      billingAccount: billingAccount,
      orgId: organizationId,
      labels: {
        environment: environment,
        "managed-by": "pulumi",
      },
    },
    {
      protect: environment === "prod", // Protect production project from accidental deletion
    }
  );

  // ============================================================================
  // Enable required APIs
  // ============================================================================

  const requiredApis = [
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
  ];

  if (enableAuth) {
    requiredApis.push("identitytoolkit.googleapis.com");
  }

  if (enableFirestore) {
    requiredApis.push("firestore.googleapis.com");
  }

  if (enableStorage) {
    requiredApis.push("storage.googleapis.com");
    requiredApis.push("storage-api.googleapis.com");
  }

  if (enableFunctions) {
    requiredApis.push("cloudfunctions.googleapis.com");
    requiredApis.push("cloudbuild.googleapis.com");
    requiredApis.push("run.googleapis.com");
  }

  const enabledApis: gcp.projects.Service[] = [];
  for (const api of requiredApis) {
    const service = new gcp.projects.Service(
      `${projectName}-api-${api.replace(/\./g, "-")}`,
      {
        project: project.projectId,
        service: api,
        disableDependentServices: false,
        disableOnDestroy: false,
      }
    );
    enabledApis.push(service);
  }

  // ============================================================================
  // Initialize Firebase (using gcloud command)
  // ============================================================================

  const firebaseInit = new command.local.Command(
    `${projectName}-firebase-init`,
    {
      create: pulumi.interpolate`gcloud firebase projects:addfirebase ${project.projectId}`,
      update: pulumi.interpolate`echo "Firebase already initialized for ${project.projectId}"`,
    },
    {
      dependsOn: enabledApis,
    }
  );

  // ============================================================================
  // Create Firebase Web App (to get config)
  // ============================================================================

  const webApp = new command.local.Command(
    `${projectName}-web-app`,
    {
      create: pulumi.interpolate`firebase apps:create web "${projectName}-web" --project=${project.projectId} -j`,
    },
    {
      dependsOn: [firebaseInit],
    }
  );

  // Get web API key from Firebase config
  const webConfig = new command.local.Command(
    `${projectName}-web-config`,
    {
      create: pulumi.interpolate`firebase apps:sdkconfig web --project=${project.projectId} -j`,
    },
    {
      dependsOn: [webApp],
    }
  );

  // ============================================================================
  // Register Android App
  // ============================================================================

  const androidApp = new command.local.Command(
    `${projectName}-android-app`,
    {
      create: pulumi.interpolate`firebase apps:create android ${androidPackageName} --project=${project.projectId}`,
    },
    {
      dependsOn: [firebaseInit],
    }
  );

  // Download google-services.json
  const googleServicesJson = new command.local.Command(
    `${projectName}-google-services-json`,
    {
      create: pulumi.interpolate`firebase apps:sdkconfig android ${androidPackageName} --project=${project.projectId} -o /tmp/google-services-${projectName}.json && cat /tmp/google-services-${projectName}.json | base64`,
    },
    {
      dependsOn: [androidApp],
    }
  );

  // ============================================================================
  // Register iOS App
  // ============================================================================

  const iosApp = new command.local.Command(
    `${projectName}-ios-app`,
    {
      create: pulumi.interpolate`firebase apps:create ios ${iosBundleId} --project=${project.projectId}`,
    },
    {
      dependsOn: [firebaseInit],
    }
  );

  // Download GoogleService-Info.plist
  const googleServicesPlist = new command.local.Command(
    `${projectName}-google-services-plist`,
    {
      create: pulumi.interpolate`firebase apps:sdkconfig ios ${iosBundleId} --project=${project.projectId} -o /tmp/GoogleService-Info-${projectName}.plist && cat /tmp/GoogleService-Info-${projectName}.plist | base64`,
    },
    {
      dependsOn: [iosApp],
    }
  );

  // ============================================================================
  // Setup Firestore
  // ============================================================================

  let firestoreDatabase: command.local.Command | undefined;
  if (enableFirestore) {
    firestoreDatabase = new command.local.Command(
      `${projectName}-firestore`,
      {
        create: pulumi.interpolate`gcloud firestore databases create --project=${project.projectId} --location=${firestoreRegion} --type=firestore-native || echo "Firestore already exists"`,
      },
      {
        dependsOn: enabledApis,
      }
    );
  }

  // ============================================================================
  // Setup Storage
  // ============================================================================

  let storageBucket: gcp.storage.Bucket | undefined;
  if (enableStorage) {
    storageBucket = new gcp.storage.Bucket(
      `${projectName}-storage`,
      {
        project: project.projectId,
        name: `${projectName}.appspot.com`,
        location: "EU",
        uniformBucketLevelAccess: true,
        cors: [
          {
            origins: ["*"],
            methods: ["GET", "HEAD", "PUT", "POST", "DELETE"],
            responseHeaders: ["*"],
            maxAgeSeconds: 3600,
          },
        ],
      },
      {
        dependsOn: enabledApis,
      }
    );
  }

  // ============================================================================
  // Create Service Account for CI/CD
  // ============================================================================

  const serviceAccount = new gcp.serviceaccount.Account(
    `${projectName}-sa`,
    {
      project: project.projectId,
      accountId: `${projectName}-cicd`,
      displayName: `CI/CD Service Account for ${projectName}`,
      description: "Service account for GitHub Actions CI/CD",
    },
    {
      dependsOn: enabledApis,
    }
  );

  // Grant necessary roles to service account
  const roles = [
    "roles/firebase.admin",
    "roles/firebaseauth.admin",
    "roles/datastore.user",
    "roles/cloudfunctions.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
  ];

  const iamBindings: gcp.projects.IAMMember[] = [];
  for (const role of roles) {
    const binding = new gcp.projects.IAMMember(
      `${projectName}-sa-${role.replace(/\//g, "-").replace(/\./g, "-")}`,
      {
        project: project.projectId,
        role: role,
        member: pulumi.interpolate`serviceAccount:${serviceAccount.email}`,
      }
    );
    iamBindings.push(binding);
  }

  // Create service account key
  const serviceAccountKey = new gcp.serviceaccount.Key(
    `${projectName}-sa-key`,
    {
      serviceAccountId: serviceAccount.name,
    },
    {
      dependsOn: iamBindings,
    }
  );

  // ============================================================================
  // Deploy Security Rules (if applicable)
  // ============================================================================

  if (enableFirestore || enableStorage) {
    // Firestore rules
    if (enableFirestore && firestoreDatabase) {
      const firestoreRules = new command.local.Command(
        `${projectName}-firestore-rules`,
        {
          create: pulumi.interpolate`echo 'rules_version = "2";
service cloud.firestore {
  match /databases/{database}/documents {
    // Default: Deny all access
    match /{document=**} {
      allow read, write: if false;
    }

    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Public read for certain collections (customize as needed)
    match /public/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}' > /tmp/firestore-${projectName}.rules && firebase deploy --only firestore:rules --project=${project.projectId}`,
        },
        {
          dependsOn: [firestoreDatabase],
        }
      );
    }

    // Storage rules
    if (enableStorage && storageBucket) {
      const storageRules = new command.local.Command(
        `${projectName}-storage-rules`,
        {
          create: pulumi.interpolate`echo 'rules_version = "2";
service firebase.storage {
  match /b/{bucket}/o {
    // Default: Deny all access
    match /{allPaths=**} {
      allow read, write: if false;
    }

    // Users can read/write their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Public read access
    match /public/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}' > /tmp/storage-${projectName}.rules && firebase deploy --only storage --project=${project.projectId}`,
        },
        {
          dependsOn: [storageBucket],
        }
      );
    }
  }

  // ============================================================================
  // Return outputs
  // ============================================================================

  return {
    projectId: project.projectId,
    projectNumber: project.number,
    webApiKey: webConfig.stdout.apply((config) => {
      try {
        const parsed = JSON.parse(config);
        return parsed.sdkConfig?.apiKey || "";
      } catch {
        return "";
      }
    }),
    serviceAccountEmail: serviceAccount.email,
    serviceAccountKey: serviceAccountKey.privateKey,
    googleServicesJson: googleServicesJson.stdout,
    googleServicesPlist: googleServicesPlist.stdout,
  };
}
