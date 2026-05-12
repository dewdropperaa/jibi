# Jenkins Credentials Documentation

## Credential Naming Convention

All credentials follow the convention: `<project>-<service>-<type>`

Where:
- `<project>`: Project identifier (e.g., `myapp`)
- `<service>`: Service being authenticated to (e.g., `android`, `firebase`, `supabase`)
- `<type>`: Credential type (e.g., `keystore`, `token`, `sa-json`, `appid`, `projectid`, `keyalias`, `keypwd`, `storepwd`)

## Credential Mapping (Before → After)

| Old ID (deprecated) | New ID | Type | Description |
|---|---|---|---|
| `keystore-file` | `myapp-android-keystore` | Secret File | Android release keystore file (`.jks`) |
| `firebase-token` | `myapp-firebase-sa-json` | Secret File | Firebase service account JSON key |
| `firebase-app-id` | `myapp-firebase-appid` | Secret Text | Firebase App ID for App Distribution |
| `supabase-access-token` | `myapp-supabase-token` | Secret Text | Supabase access token for CLI |
| `supabase-project-id` | `myapp-supabase-projectid` | Secret Text | Supabase project reference ID |
| `key-alias` | `myapp-android-keyalias` | Secret Text | Keystore key alias for signing APKs |
| `key-password` | `myapp-android-keypwd` | Secret Text | Keystore key password |
| `store-password` | `myapp-android-storepwd` | Secret Text | Keystore store password |

## Credentials Required for CI/CD Pipeline

### CI Credentials (ci-agent service account — read-only)

| Credential ID | Type | Description | Used In |
|---|---|---|---|
| `sonarqube-token` | Secret Text | SonarQube authentication token | SAST - SonarQube stage |
| `github-webhook-secret` | Secret Text | HMAC secret for GitHub webhook validation | Pipeline triggers |

### CD Credentials (cd-agent service account — full access)

#### Signing Credentials

| Credential ID | Type | Description |
|---|---|---|
| `myapp-android-keystore` | Secret File | Android release keystore file (`.jks`) |
| `myapp-android-keyalias` | Secret Text | Keystore key alias for signing APKs |
| `myapp-android-keypwd` | Secret Text | Keystore key password |
| `myapp-android-storepwd` | Secret Text | Keystore store password |

#### Firebase Credentials

| Credential ID | Type | Description |
|---|---|---|
| `myapp-firebase-appid` | Secret Text | Firebase App ID for App Distribution |
| `myapp-firebase-sa-json` | Secret File | Google Service Account JSON key for Firebase CLI. Replaces the deprecated `--token` approach. The pipeline writes this to a temp file and sets `GOOGLE_APPLICATION_CREDENTIALS` env var. |

#### Supabase Credentials

| Credential ID | Type | Description |
|---|---|---|
| `myapp-supabase-token` | Secret Text | Supabase access token for CLI authentication |
| `myapp-supabase-projectid` | Secret Text | Supabase project reference ID |

#### SAST / Security Credentials

| Credential ID | Type | Description |
|---|---|---|
| `mobsf-api-key` | Secret Text | MobSF API key for static analysis scanning |

#### Notification Credentials

| Credential ID | Type | Description |
|---|---|---|
| `slack-webhook-url` | Secret Text | Slack incoming webhook URL for build notifications |

## Service Account Separation

| Service Account | Role | Scope |
|---|---|---|
| `ci-agent` | Read-only access to CI credentials | ktlint, Detekt, SonarQube, OWASP |
| `cd-agent` | Full access to CD credentials | Signing, Firebase, Supabase, MobSF |

Each service account is a Jenkins user with specific credential permissions.
The pipeline uses `withCredentials()` scoped per stage to load only the
credentials needed for that stage.

## How to Add Credentials

1. Navigate to **Manage Jenkins** → **Credentials** → **System** → **Global credentials (unrestricted)**
2. Click **Add Credentials**
3. Select the appropriate kind (Secret Text / Secret File)
4. Fill in the ID (following the naming convention above) and value
5. Click **OK**

## Credential Audit

Run this script periodically to audit credential usage:

```bash
# List all credentials in Jenkins (requires admin access)
curl -u "admin:password" \
  "http://jenkins.example.com/credentials/store/system/domain/_/api/json?pretty=true"
```

Review the audit log in Jenkins:
1. Navigate to **Manage Jenkins** → **Audit Trail**
2. Filter by credential-related events

## Firebase Service Account Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **IAM & Admin** → **Service Accounts**
3. Create a new service account (e.g., `firebase-ci-deployer`)
4. Grant it the **Firebase App Distribution Admin** role
5. Create and download a JSON key file
6. Upload the JSON file to Jenkins as a **Secret File** credential with ID `myapp-firebase-sa-json`
