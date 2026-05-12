# CI/CD Runbook — Jenkins Pipeline Operations

## Table of Contents

1. [Pipeline Overview](#pipeline-overview)
2. [Credential Management](#credential-management)
3. [Build Operations](#build-operations)
4. [Database Migration Rollback](#database-migration-rollback)
5. [Backup and Restore](#backup-and-restore)
6. [Incident Response](#incident-response)
7. [Troubleshooting](#troubleshooting)
8. [Escalation Contacts](#escalation-contacts)

## Pipeline Overview

### Architecture

```
GitHub (push/webhook)
  -> Jenkins CI/CD Pipeline (Kubernetes agent)
    -> CI Stage: ktlint, Detekt, Unit Tests, OWASP CVE Scan, SonarQube
    -> CD Stage: Build Signed APK, Firebase Distribution, Supabase Migration, MobSF SAST
```

### Branch Strategy

| Branch | CI Stage | CD Stage |
|---|---|---|
| `main` | Runs on every push | Runs after CI passes |
| `develop` | Runs on every push | Skipped |
| Feature branches | Runs on every push | Skipped |

### Pipeline Stages

```
CI:
  1. Checkout (shallow clone, depth=1)
  2. Parallel:
     - ktlint (code style)
     - Detekt (static analysis)
     - SonarQube (SAST)
     - OWASP Dependency-Check (CVE scanning)
     - Unit Tests

CD (main only):
  1. Decode Keystore
  2. Build Release APK (signed, versionCode auto-incremented)
  3. Verify APK Signature
  4. Firebase App Distribution
  5. Supabase Migration (with backup/rollback)
  6. MobSF SAST Scan
  7. Archive APK
```

## Credential Management

### Credential Naming Convention

All credentials follow the pattern: `<project>-<service>-<type>`

| Credential ID | Type | Purpose |
|---|---|---|
| `myapp-android-keystore` | Secret File | Android release keystore (.jks) |
| `myapp-android-keyalias` | Secret Text | Keystore key alias |
| `myapp-android-keypwd` | Secret Text | Keystore key password |
| `myapp-android-storepwd` | Secret Text | Keystore store password |
| `myapp-firebase-sa-json` | Secret File | Firebase service account JSON |
| `myapp-firebase-appid` | Secret Text | Firebase App ID |
| `myapp-supabase-token` | Secret Text | Supabase access token |
| `myapp-supabase-projectid` | Secret Text | Supabase project reference ID |
| `slack-webhook-url` | Secret Text | Slack notifications |
| `github-webhook-secret` | Secret Text | GitHub webhook HMAC validation |
| `mobsf-api-key` | Secret Text | MobSF SAST API key |

### Credential Separation

| Service Account | Access Level | Credentials |
|---|---|---|
| `ci-agent` | Read-only (lint/test) | ktlint, Detekt, SonarQube, OWASP |
| `cd-agent` | Full access | Signing, Firebase, Supabase, MobSF |

### How to Add a Credential

1. Navigate to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Select type (Secret Text / Secret File)
4. Enter the ID following the naming convention above
5. Click **OK**

## Build Operations

### Manual Build Trigger

1. Navigate to the Jenkins job page
2. Click **Build with Parameters**
3. Select the target branch
4. Click **Build**

### Force CD Stage on develop (for testing)

1. Edit the Jenkinsfile temporarily to change `branch 'main'` to `branch 'develop'`
2. Commit and push
3. **Remove the temporary change immediately after testing**

### Add a New Tester to Firebase App Distribution

1. Open the [Firebase Console](https://console.firebase.google.com/)
2. Select the project
3. Navigate to **App Distribution** → **Testers**
4. Click **Add tester**
5. Enter the tester's email address
6. Assign the tester to the `internal-team` group
7. The tester will receive an invitation email to join the testing program

Alternatively, via Firebase CLI:

```bash
firebase appdistribution:testers:add "tester@example.com" --project <project-id>
```

### Rebuild a Specific Stage

1. Navigate to the build page
2. Click **Replay** to re-run with the same parameters
3. Or click **Rebuild** to start a fresh build

## Database Migration Rollback

### Automatic Rollback (Pipeline)

The pipeline automatically backs up the database before running migrations:

1. Before `supabase db push`: runs `supabase db dump -f pre_migration_backup.sql`
2. After `supabase db push`: if exit code != 0, runs `supabase db restore pre_migration_backup.sql`
3. In `post { always {} }`: deletes the backup file

### Manual Rollback Procedure

If a migration causes issues in production, follow these steps:

#### Step 1: Identify the problematic migration

```bash
supabase db remote status --project-ref <project-id> --access-token <token>
supabase db diff --project-ref <project-id> --access-token <token>
```

#### Step 2: Restore from backup (if available from pipeline run)

```bash
supabase db restore pre_migration_backup.sql --project-ref <project-id> --access-token <token>
```

#### Step 3: Restore from manual backup (if pipeline backup was deleted)

```bash
supabase db restore /path/to/manual_backup.sql --project-ref <project-id> --access-token <token>
```

#### Step 4: Create a down migration (preferred for production)

```bash
supabase migration new rollback_<description>
```

Edit the new migration file to reverse the changes:

```sql
-- Example: drop a table that was added
DROP TABLE IF EXISTS new_table CASCADE;

-- Example: revert a column change
ALTER TABLE users DROP COLUMN IF EXISTS new_column;
ALTER TABLE users ADD COLUMN old_column VARCHAR(255) DEFAULT NULL;
```

Apply the down migration:

```bash
supabase db push --project-ref <project-id> --access-token <token>
```

#### Step 5: Verify the rollback

```bash
supabase db remote status --project-ref <project-id> --access-token <token>
```

#### Step 6: Notify the team

Post in the #ci-notifications Slack channel with details of the rollback and
the affected migration.

### Emergency Rollback Checklist

- [ ] Identify the problematic migration and its impact
- [ ] Stop the pipeline to prevent further migrations
- [ ] Restore from the latest backup or apply down migration
- [ ] Verify database integrity and application functionality
- [ ] Notify the team and document the incident
- [ ] Create a fix in a feature branch and re-test
- [ ] Re-enable the pipeline after validation

## Backup and Restore

### Automated Backups

Backups run daily at 2:00 AM UTC via Kubernetes CronJob.

- **Script**: `scripts/backup_jenkins.sh`
- **Schedule**: `0 2 * * *`
- **Destination**: Configurable via `BACKUP_DESTINATION` env var (S3, GCS, Azure Blob)
- **Retention**: Last 30 backups
- **Encryption**: GPG encrypted before upload

### Manual Backup

```bash
kubectl create job manual-backup --from=cronjob/jenkins-backup -n jenkins
```

### Restore from Backup

1. Download the backup:

```bash
aws s3 cp s3://my-backups/jenkins/jenkins-<timestamp>.tar.gz.gpg ./
```

2. Decrypt:

```bash
gpg --decrypt jenkins-<timestamp>.tar.gz.gpg > jenkins-<timestamp>.tar.gz
```

3. Restore to Jenkins PVC:

```bash
kubectl cp jenkins-<timestamp>.tar.gz <jenkins-pod>:/tmp/ -n jenkins
kubectl exec <jenkins-pod> -n jenkins -- tar xzf /tmp/jenkins-<timestamp>.tar.gz -C /var/jenkins_home
```

4. Restart Jenkins:

```bash
kubectl rollout restart deployment/jenkins -n jenkins
```

## Incident Response

### Build Failures

1. Check the build console output for the specific error
2. Verify credentials are configured correctly
3. Check if the agent pod started successfully
4. Review the Slack notification for build status

### Pipeline Stuck

1. Check Kubernetes pod status: `kubectl get pods -n jenkins`
2. Check for resource constraints: `kubectl describe pod <pod-name> -n jenkins`
3. Aborting the build from Jenkins UI and retrying

### Database Migration Failed

1. Follow the [Manual Rollback Procedure](#manual-rollback-procedure)
2. Check Supabase dashboard for migration logs
3. Verify the migration SQL syntax locally before re-running

### Firebase Distribution Failed

1. Verify the Firebase service account JSON is valid and not expired
2. Check the Firebase App ID is correct
3. Verify the APK was built successfully
4. Retry the build (pipeline has retry(3) logic)

## Troubleshooting

### Common Issues and Solutions

| Issue | Cause | Solution |
|---|---|---|
| `BUILD_NUMBER` not set | Jenkins misconfiguration | Ensure `BUILD_NUMBER` env var is available |
| `supabase: command not found` | Agent image missing CLI | Update agent image to include Supabase CLI |
| `firebase: command not found` | Agent image missing CLI | Update agent image to include Firebase CLI |
| APK signing failure | Keystore credentials wrong | Verify all 4 keystore credentials in Jenkins |
| Network timeout | Kubernetes egress policy | Check NetworkPolicy allows required egress |
| PVC mount failure | StorageClass mismatch | Verify StorageClass exists and matches PVC spec |
| Agent pod won't start | RBAC permissions missing | Verify ServiceAccount and RoleBinding |
| TLS certificate error | cert-manager not installed | Install cert-manager and ClusterIssuer |

### Useful Commands

```bash
# Check Jenkins pod status
kubectl get pods -n jenkins

# View Jenkins logs
kubectl logs -n jenkins deploy/jenkins -f

# Check agent pods
kubectl get pods -n jenkins -l jenkins-agent=android

# View pipeline console output
kubectl logs -n jenkins <agent-pod-name>

# Check PVC status
kubectl get pvc -n jenkins

# Check network policies
kubectl get networkpolicy -n jenkins

# Check ingress status
kubectl get ingress -n jenkins

# Restart Jenkins
kubectl rollout restart deployment/jenkins -n jenkins

# Check CronJob status
kubectl get cronjob -n jenkins
```

## Escalation Contacts

| Role | Contact | Responsibility |
|---|---|---|
| DevOps Lead | devops-lead@example.com | Pipeline configuration, K8s issues |
| Android Lead | android-lead@example.com | Build/gradle issues, signing |
| Backend Lead | backend-lead@example.com | Supabase migration issues |
| Security Lead | security-lead@example.com | SAST, CVE, compliance issues |
| On-Call Engineer | #on-call Slack channel | General incident response |
