# Local Jenkins Setup

This document describes the recommended professional local Jenkins setup for this repository.

## Purpose

Use `Jenkinsfile.local` when you want a stable Jenkins validation pipeline on a single Windows machine before investing in the full production Jenkins platform.

Use the main `Jenkinsfile` only after the broader Jenkins platform is ready, because it assumes:

- Kubernetes-based Jenkins agents
- a Jenkins shared library
- external credentials and service integrations

## Prerequisites

- Java 21 installed
- Git installed
- Android SDK installed on the Jenkins machine
- Jenkins with the following plugins:
  - `workflow-aggregator`
  - `git`
  - `junit`

## Recommended Job Configuration

Create a Jenkins **Pipeline** job and configure it as:

- **Definition**: `Pipeline script from SCM`
- **SCM**: `Git`
- **Repository URL**: your repository URL or a local file-based repository path
- **Branch Specifier**: `*/main`
- **Script Path**: `Jenkinsfile.local`

## What `Jenkinsfile.local` Does

1. Verifies that the Jenkins workspace is the Android project root
2. Generates `local.properties` automatically if it is missing but the Android SDK exists under `%LOCALAPPDATA%\Android\Sdk`
3. Runs:
   - `gradlew.bat ktlintCheck`
   - `gradlew.bat detekt`
   - `gradlew.bat test`
4. Archives test results and reports
5. Optionally runs a release signing dry-run when these environment variables are provided:
   - `KEYSTORE_BASE64`
   - `KEY_ALIAS`
   - `KEY_PASSWORD`
   - `STORE_PASSWORD`

## Recommended Promotion Path

1. Keep `Jenkinsfile.local` green on the main branch
2. Add Jenkins-managed credentials for signing and external services
3. Stand up shared libraries and agent infrastructure
4. Migrate the job to the main `Jenkinsfile`

## Notes

- `local.properties` stays ignored by Git and is generated inside the Jenkins workspace when needed
- The local Jenkins pipeline is intentionally narrower than the production pipeline
- If you move from a local file-based repository path to a remote Git host, keep the same script path: `Jenkinsfile.local`
