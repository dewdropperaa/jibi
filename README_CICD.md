# CI/CD Setup for Android + Supabase

This repository includes GitHub Actions pipelines for:

- Continuous Integration: `.github/workflows/ci.yml`
- Continuous Delivery: `.github/workflows/cd.yml`

The CD pipeline builds a signed Android release APK, distributes it to Firebase App Distribution (internal testers), and applies Supabase migrations to production.

## Workflows

### CI (`ci.yml`)

Runs on every push and pull request to `main` and `develop`:

- Checkout code
- Set up JDK 17
- Cache Gradle dependencies
- Run `ktlintCheck`
- Run `detekt`
- Run unit tests (`./gradlew test`)
- Run optional instrumented tests (skippable)
- Upload reports as artifacts

### CD (`cd.yml`)

Runs on every push to `main` (including merges):

- Checkout code
- Set up JDK 17
- Decode Android keystore from secrets
- Build signed release APK (`./gradlew assembleRelease`)
- Upload APK to Firebase App Distribution group `internal-team`
- Upload APK to GitHub Actions artifacts as backup
- Run Supabase CLI migrations against production project

## Required GitHub Secrets

Add the following repository secrets in **GitHub -> Settings -> Secrets and variables -> Actions**:

1. `KEYSTORE_BASE64`  
   Base64-encoded Android keystore file (`.jks` or `.keystore`).

2. `KEY_ALIAS`  
   Alias name of the signing key inside the keystore.

3. `KEY_PASSWORD`  
   Password for the signing key alias.

4. `STORE_PASSWORD`  
   Password for the keystore file.

5. `FIREBASE_TOKEN`  
   Firebase CI token generated from `firebase login:ci`.

6. `FIREBASE_APP_ID`  
   Firebase Android App ID (format similar to `1:1234567890:android:abc123...`).

7. `SUPABASE_ACCESS_TOKEN`  
   Supabase personal access token used by Supabase CLI.

8. `SUPABASE_PROJECT_ID`  
   Supabase project ref ID for the production project.

## How to Create `KEYSTORE_BASE64`

From your local machine:

```bash
base64 -i release.keystore | tr -d '\n'
```

Copy the output and save it as the `KEYSTORE_BASE64` secret.

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore"))
```

## Install Firebase CLI (local)

Install Node.js first, then:

```bash
npm install -g firebase-tools
firebase login
firebase login:ci
```

Use the generated token as `FIREBASE_TOKEN`.

To get `FIREBASE_APP_ID`, open **Firebase Console -> Project settings -> Your apps -> Android app**.

## Supabase CLI and Project Linking

Install Supabase CLI locally if needed:

```bash
npm install -g supabase
```

Authenticate and link:

```bash
supabase login
supabase link --project-ref <your-project-ref>
```

The workflow uses:

- `SUPABASE_ACCESS_TOKEN` for authentication
- `SUPABASE_PROJECT_ID` as `--project-ref`

Make sure your SQL migrations are committed under the standard Supabase migrations directory before merging to `main`.

## Notes

- No secrets are hardcoded in workflows; all sensitive values come from `${{ secrets.* }}`.
- Firebase distribution targets the tester group: `internal-team`.
- The latest git commit message is used as Firebase release notes.
