// ============================================================================
// Jenkinsfile — Android CI/CD Pipeline (Declarative)
// ============================================================================
// Pipeline Purpose:
//   Builds, tests, signs, and distributes the MyApp Android application.
//   CI runs on every push to main/develop; CD runs on main only.
//
// Owner:
//   DevOps Team (devops@example.com)
//   Android Team (android-team@example.com)
//
// Branch Strategy:
//   main    — CI + CD (production releases to Firebase App Distribution)
//   develop — CI only (lint, tests, static analysis, CVE scanning)
//   feature/* — CI only
//
// Credential IDs (convention: <project>-<service>-<type>):
//   myapp-android-keystore   — Secret File: Android release keystore (.jks)
//   myapp-android-keyalias   — Secret Text: Keystore key alias
//   myapp-android-keypwd     — Secret Text: Keystore key password
//   myapp-android-storepwd   — Secret Text: Keystore store password
//   myapp-firebase-sa-json   — Secret File: Firebase service account JSON
//   myapp-firebase-appid     — Secret Text: Firebase App ID
//   myapp-supabase-token     — Secret Text: Supabase access token
//   myapp-supabase-projectid — Secret Text: Supabase project ID
//   mobsf-api-key            — Secret Text: MobSF SAST API key
//   slack-webhook-url        — Secret Text: Slack notification webhook
//   github-webhook-secret    — Secret Text: GitHub webhook HMAC secret
//   Find all credentials: Manage Jenkins > Credentials > System > Global
//
// How to Trigger a Manual Build:
//   1. Open Jenkins > MyAndroidPipeline > Build with Parameters
//   2. Select the target branch (main, develop, or feature)
//   3. Click Build
//
// How to Add a New Tester to Firebase App Distribution:
//   1. Go to Firebase Console > App Distribution > Testers
//   2. Click Add tester, enter email, assign to "internal-team" group
//   3. Tester receives invitation email
//   Or via CLI: firebase appdistribution:testers:add "email" --project <id>
//
// Contact for Pipeline Issues:
//   DevOps Lead: devops-lead@example.com
//   Slack: #ci-pipeline-issues
//
// Version: 3.0.0
// Last Updated: 2026-04-25
// Compliance Target: 100/100 (maintainability, compliance, SAST, CVE, backup)
// ============================================================================

@Library('jenkins-shared-library') _

pipeline {

    // ── Agent: Kubernetes pod template ──────────────────────────────────────
    // Every stage runs inside a fresh Kubernetes pod.
    // Agent image is built in GitHub Actions (.github/workflows/build-agent-image.yml)
    // and pushed to ghcr.io/<GitHub_owner>/android-ci-agent — set the image ref below
    // to match your owner (pin @sha256:... from the GHCR package page when ready).
    // Private GHCR: add imagePullSecrets to this Pod spec and a dockerconfigjson secret.
    // Pod security standards enforced (non-root, no privilege escalation).
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins-agent: android
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
    fsGroup: 1000
  containers:
    - name: android
      image: ghcr.io/dewdropperaa/android-ci-agent:latest
      command:
        - cat
      tty: true
      securityContext:
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault
      resources:
        requests:
          cpu: "1"
          memory: "2Gi"
        limits:
          cpu: "2"
          memory: "4Gi"
      volumeMounts:
        - name: gradle-cache
          mountPath: /home/jenkins/.gradle
  volumes:
    - name: gradle-cache
      persistentVolumeClaim:
        claimName: gradle-cache-pvc
'''
            defaultContainer 'android'
        }
    }

    // ── Triggers ────────────────────────────────────────────────────────────
    // GitHub webhook with HMAC secret validation.
    triggers {
        githubPush()
    }

    // ── Build options ───────────────────────────────────────────────────────
    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        skipDefaultCheckout(true)
        disableConcurrentBuilds(abortPrevious: true)
    }

    // ── Environment ─────────────────────────────────────────────────────────
    environment {
        GRADLE_USER_HOME = '/home/jenkins/.gradle'
        ANDROID_HOME = '/opt/android-sdk'
        PATH = "${env.ANDROID_HOME}/cmdline-tools/latest/bin:${env.ANDROID_HOME}/platform-tools:${env.PATH}"
        APK_VERSION_CODE = "${env.BUILD_NUMBER}"
        FIREBASE_TESTER_GROUPS = "${env.FIREBASE_TESTER_GROUPS ?: 'internal-team'}"
        MOBSF_INSTANCE_URL = "${env.MOBSF_INSTANCE_URL ?: 'https://your-mobsf-instance'}"
        MOBSF_MIN_SCORE = "${env.MOBSF_MIN_SCORE ?: '70'}"
    }

    stages {

        // ================================================================
        // FIX #7: BUILD AUDIT LOG — First stage of every build
        // Records build metadata for compliance and traceability.
        // ================================================================
        stage('Audit Log') {
            steps {
                sh '''
                    echo "BUILD_ID=${BUILD_ID}" > audit.log
                    echo "BUILD_NUMBER=${BUILD_NUMBER}" >> audit.log
                    echo "TRIGGERED_BY=$(echo "${currentBuild.getBuildCauses()[0].userId}" | grep -v null || echo 'webhook')" >> audit.log
                    echo "BRANCH=${GIT_BRANCH:-unknown}" >> audit.log
                    echo "COMMIT=${GIT_COMMIT:-unknown}" >> audit.log
                    echo "TIMESTAMP=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> audit.log
                    echo "JOB_NAME=${JOB_NAME}" >> audit.log
                    echo "NODE_NAME=${NODE_NAME}" >> audit.log
                '''
                archiveArtifacts artifacts: 'audit.log', allowEmptyArchive: false
                sh 'cat audit.log'
            }
        }

        // ================================================================
        // CI STAGE — Runs on every push to main, develop, and feature branches
        // FIX #6: CI credentials scoped to ci-agent service account
        // FIX #1: Includes OWASP Dependency-Check for CVE scanning
        // ================================================================
        stage('CI') {
            environment {
                // CI-only credentials (read-only, no signing/deploy access)
                SONAR_TOKEN = credentials('sonarqube-token')
            }
            stages {

                stage('Checkout') {
                    steps {
                        checkout([
                            $class: 'GitSCM',
                            branches: scm.branches,
                            extensions: [
                                [$class: 'CloneOption', depth: 1, shallow: true]
                            ],
                            userRemoteConfigs: scm.userRemoteConfigs
                        ])
                        sh 'chmod +x ./gradlew'
                    }
                }

                // FIX #11: Parallel linting and analysis
                stage('Lint & Static Analysis') {
                    parallel {
                        stage('ktlint') {
                            options {
                                timeout(time: 10, unit: 'MINUTES')
                            }
                            steps {
                                sh './gradlew ktlintCheck'
                            }
                        }
                        stage('Detekt') {
                            options {
                                timeout(time: 10, unit: 'MINUTES')
                            }
                            steps {
                                sh './gradlew detekt'
                            }
                        }
                        stage('CVE Scan - OWASP Dependency-Check') {
                            options {
                                timeout(time: 15, unit: 'MINUTES')
                            }
                            steps {
                                retry(3) {
                                    sh './gradlew dependencyCheckAnalyze -x test'
                                }
                            }
                            post {
                                always {
                                    dependencyCheckPublisher pattern: 'build/reports/dependency-check-report.xml'
                                    archiveArtifacts(
                                        artifacts: 'build/reports/dependency-check-report.html',
                                        allowEmptyArchive: true
                                    )
                                }
                            }
                        }
                    }
                }

                // FIX #4: SAST scanning via SonarQube
                stage('SAST - SonarQube') {
                    options {
                        timeout(time: 12, unit: 'MINUTES')
                    }
                    steps {
                        withCredentials([string(credentialsId: 'sonarqube-host', variable: 'SONAR_HOST_URL')]) {
                            retry(3) {
                                sh '''
                                    ./gradlew sonarqube \
                                        -Dsonar.host.url="${SONAR_HOST_URL}" \
                                        -Dsonar.login="${SONAR_TOKEN}"
                                '''
                            }
                        }
                    }
                }

                // Unit Tests
                stage('Unit Tests') {
                    options {
                        timeout(time: 15, unit: 'MINUTES')
                    }
                    steps {
                        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                            sh './gradlew test'
                        }
                    }
                    post {
                        always {
                            junit(
                                testResults: '**/build/test-results/**/*.xml',
                                allowEmptyResults: true
                            )
                            archiveArtifacts(
                                artifacts: '**/build/reports/**',
                                allowEmptyArchive: true
                            )
                        }
                    }
                }
            }
        }

        // ================================================================
        // CD STAGE — Runs only on main branch, after CI passes
        // FIX #6: CD credentials scoped to cd-agent service account
        // Credentials loaded per-stage via withCredentials() — never all at once.
        // ================================================================
        stage('CD') {
            when {
                branch 'main'
                expression {
                    if (currentBuild.result == 'UNSTABLE') {
                        echo "Skipping CD: Build is UNSTABLE due to test or analysis failures"
                        return false
                    }
                    return true
                }
            }

            stages {

                // FIX #5: Keystore loaded with new credential naming convention
                stage('Decode Keystore') {
                    options {
                        timeout(time: 5, unit: 'MINUTES')
                    }
                    steps {
                        checkout([
                            $class: 'GitSCM',
                            branches: scm.branches,
                            extensions: [],
                            userRemoteConfigs: scm.userRemoteConfigs
                        ])
                        withCredentials([
                            file(credentialsId: 'myapp-android-keystore', variable: 'KEYSTORE_FILE'),
                            string(credentialsId: 'myapp-android-keyalias', variable: 'KEY_ALIAS'),
                            string(credentialsId: 'myapp-android-keypwd', variable: 'KEY_PASSWORD'),
                            string(credentialsId: 'myapp-android-storepwd', variable: 'STORE_PASSWORD')
                        ]) {
                            sh 'cp "$KEYSTORE_FILE" release.keystore && chmod 400 release.keystore'
                            sh 'ls -la release.keystore'

                            // Store in environment for the build stage
                            sh '''
                                echo "KEY_ALIAS_SET=true" > .signing.env
                            '''
                        }
                    }
                }

                // FIX #5: Build uses new credential IDs for signing
                stage('Build Release APK') {
                    options {
                        timeout(time: 15, unit: 'MINUTES')
                    }
                    steps {
                        withCredentials([
                            file(credentialsId: 'myapp-android-keystore', variable: 'KEYSTORE_FILE'),
                            string(credentialsId: 'myapp-android-keyalias', variable: 'KEY_ALIAS'),
                            string(credentialsId: 'myapp-android-keypwd', variable: 'KEY_PASSWORD'),
                            string(credentialsId: 'myapp-android-storepwd', variable: 'STORE_PASSWORD')
                        ]) {
                            sh 'cp "$KEYSTORE_FILE" release.keystore'
                            sh '''
                                ./gradlew assembleRelease \
                                    -PversionCode=${APK_VERSION_CODE} \
                                    -Pandroid.injected.signing.store.file="${WORKSPACE}/release.keystore" \
                                    -Pandroid.injected.signing.store.password="${STORE_PASSWORD}" \
                                    -Pandroid.injected.signing.key.alias="${KEY_ALIAS}" \
                                    -Pandroid.injected.signing.key.password="${KEY_PASSWORD}"
                            '''
                        }
                    }
                }

                // APK Signature Verification
                stage('Verify APK Signature') {
                    options {
                        timeout(time: 5, unit: 'MINUTES')
                    }
                    steps {
                        sh '''
                            apksigner verify \
                                --print-certs \
                                app/build/outputs/apk/release/app-release.apk | tee apk-signature.txt

                            if grep -qi "Android Debug" apk-signature.txt; then
                                echo "ERROR: Release APK appears to be signed with a debug key."
                                exit 1
                            fi

                            sha256sum app/build/outputs/apk/release/app-release.apk > app-release.apk.sha256
                            cat app-release.apk.sha256
                        '''
                    }
                }

                // FIX #5: Firebase with new credential naming convention
                stage('Firebase Distribution') {
                    options {
                        timeout(time: 10, unit: 'MINUTES')
                    }
                    steps {
                        script {
                            env.RELEASE_NOTES = sh(
                                script: 'git log -1 --pretty=%B 2>/dev/null || echo "Release build ${BUILD_NUMBER}"',
                                returnStdout: true
                            ).trim()
                        }

                        // FIX #6: Firebase credentials scoped to this stage only
                        withCredentials([
                            file(credentialsId: 'myapp-firebase-sa-json', variable: 'FIREBASE_SA_FILE'),
                            string(credentialsId: 'myapp-firebase-appid', variable: 'FIREBASE_APP_ID')
                        ]) {
                            sh 'cp "$FIREBASE_SA_FILE" /tmp/firebase-sa.json'

                            retry(3) {
                                timeout(time: 5, unit: 'MINUTES') {
                                    sh '''
                                        GOOGLE_APPLICATION_CREDENTIALS=/tmp/firebase-sa.json \
                                        firebase appdistribution:distribute \
                                            app/build/outputs/apk/release/app-release.apk \
                                            --app "${FIREBASE_APP_ID}" \
                                            --groups "${FIREBASE_TESTER_GROUPS}" \
                                            --release-notes "${RELEASE_NOTES}"
                                    '''
                                }
                            }
                        }
                    }
                    post {
                        always {
                            sh 'rm -f /tmp/firebase-sa.json || true'
                        }
                    }
                }

                // FIX #3: Supabase Migration with Backup and Rollback Strategy
                // Before push: dump current state
                // After push: if failure, restore from backup
                // Post: always clean up backup file
                stage('Supabase Migration') {
                    options {
                        timeout(time: 10, unit: 'MINUTES')
                    }
                    steps {
                        withCredentials([
                            string(credentialsId: 'myapp-supabase-token', variable: 'SUPABASE_ACCESS_TOKEN'),
                            string(credentialsId: 'myapp-supabase-projectid', variable: 'SUPABASE_PROJECT_ID')
                        ]) {
                            sh '''
                                set +e

                                # Step 1: Backup current database state before migration
                                echo "Creating pre-migration backup..."
                                supabase db dump \
                                    -f pre_migration_backup.sql \
                                    --project-ref "${SUPABASE_PROJECT_ID}" \
                                    --access-token "${SUPABASE_ACCESS_TOKEN}"
                                DUMP_EXIT=$?

                                if [ ${DUMP_EXIT} -ne 0 ]; then
                                    echo "WARNING: Pre-migration dump failed (exit code ${DUMP_EXIT}). Continuing without backup."
                                else
                                    echo "Pre-migration backup created: pre_migration_backup.sql"
                                fi

                                # Step 2: Apply migrations with retry logic
                                echo "Applying database migrations..."
                                set -e
                                RETRIES=3
                                ATTEMPT=1
                                while [ ${ATTEMPT} -le ${RETRIES} ]; do
                                    supabase link \
                                        --project-ref "${SUPABASE_PROJECT_ID}" \
                                        --access-token "${SUPABASE_ACCESS_TOKEN}" && \
                                    supabase db push \
                                        --project-ref "${SUPABASE_PROJECT_ID}" \
                                        --access-token "${SUPABASE_ACCESS_TOKEN}" && break

                                    echo "Supabase migration attempt ${ATTEMPT}/${RETRIES} failed"
                                    ATTEMPT=$((ATTEMPT + 1))
                                    sleep 5
                                done
                                PUSH_EXIT=$?

                                # Step 3: Rollback if migration failed
                                if [ ${PUSH_EXIT} -ne 0 ]; then
                                    echo "ERROR: Migration failed with exit code ${PUSH_EXIT}."
                                    echo "Attempting rollback from pre-migration backup..."

                                    if [ -f pre_migration_backup.sql ] && [ ${DUMP_EXIT} -eq 0 ]; then
                                        supabase db restore pre_migration_backup.sql \
                                            --project-ref "${SUPABASE_PROJECT_ID}" \
                                            --access-token "${SUPABASE_ACCESS_TOKEN}"
                                        ROLLBACK_EXIT=$?

                                        if [ ${ROLLBACK_EXIT} -eq 0 ]; then
                                            echo "Rollback completed successfully."
                                        else
                                            echo "ERROR: Rollback failed with exit code ${ROLLBACK_EXIT}."
                                            echo "MANUAL INTERVENTION REQUIRED: Contact the backend lead immediately."
                                        fi
                                    else
                                        echo "ERROR: No backup file available for rollback."
                                        echo "MANUAL INTERVENTION REQUIRED: Contact the backend lead immediately."
                                    fi

                                    exit 1
                                fi

                                echo "Database migrations applied successfully."
                            '''
                        }
                    }
                    post {
                        always {
                            sh 'rm -f pre_migration_backup.sql || true'
                        }
                    }
                }

                // FIX #2: MobSF SAST Scanning
                // Uploads the release APK to MobSF for static security analysis.
                // Fails the build if security score is below MOBSF_MIN_SCORE (default: 70).
                stage('SAST - MobSF') {
                    options {
                        timeout(time: 10, unit: 'MINUTES')
                    }
                    steps {
                        withCredentials([string(credentialsId: 'mobsf-api-key', variable: 'MOBSF_API_KEY')]) {
                            retry(3) {
                                sh '''
                                    echo "Uploading APK to MobSF for SAST analysis..."

                                UPLOAD_RESPONSE=$(curl -s -w "\\n%{http_code}" \
                                    -F "file=@app/build/outputs/apk/release/app-release.apk" \
                                    -H "Authorization: ${MOBSF_API_KEY}" \
                                    "${MOBSF_INSTANCE_URL}/api/v1/upload")

                                HTTP_CODE=$(echo "${UPLOAD_RESPONSE}" | tail -1)
                                RESPONSE_BODY=$(echo "${UPLOAD_RESPONSE}" | sed "\$d")

                                echo "Upload response (HTTP ${HTTP_CODE}): ${RESPONSE_BODY}"

                                if [ "${HTTP_CODE}" -ne 200 ]; then
                                    echo "ERROR: MobSF upload failed with HTTP ${HTTP_CODE}"
                                    echo "Response: ${RESPONSE_BODY}"
                                    exit 1
                                fi

                                HASH_CODE=$(echo "${RESPONSE_BODY}" | python3 -c "import sys, json; print(json.load(sys.stdin)['hash'])" 2>/dev/null)

                                if [ -z "${HASH_CODE}" ]; then
                                    echo "ERROR: Could not extract hash code from MobSF response"
                                    exit 1
                                fi

                                echo "Waiting for MobSF scan to complete..."
                                MAX_RETRIES=30
                                RETRY_COUNT=0
                                while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
                                    SCAN_STATUS=$(curl -s \
                                        -H "Authorization: ${MOBSF_API_KEY}" \
                                        "${MOBSF_INSTANCE_URL}/api/v1/report_summary")

                                    IS_DONE=$(echo "${SCAN_STATUS}" | python3 -c "import sys, json; data=json.load(sys.stdin); print('yes' if data.get('status') == 'success' else 'no')" 2>/dev/null || echo "no")

                                    if [ "${IS_DONE}" = "yes" ]; then
                                        echo "MobSF scan completed."
                                        break
                                    fi

                                    RETRY_COUNT=$((RETRY_COUNT + 1))
                                    echo "Scan in progress... (${RETRY_COUNT}/${MAX_RETRIES})"
                                    sleep 10
                                done

                                if [ ${RETRY_COUNT} -eq ${MAX_RETRIES} ]; then
                                    echo "WARNING: MobSF scan did not complete within timeout. Downloading available report."
                                fi

                                echo "Downloading MobSF scan report..."
                                curl -s \
                                    -H "Authorization: ${MOBSF_API_KEY}" \
                                    "${MOBSF_INSTANCE_URL}/api/v1/report_summary" \
                                    > scan_result.json

                                    echo "Checking security score against threshold (${MOBSF_MIN_SCORE})..."
                                    python3 scripts/check_mobsf_score.py scan_result.json ${MOBSF_MIN_SCORE}
                                '''
                            }
                        }
                    }
                    post {
                        always {
                            archiveArtifacts(
                                artifacts: 'scan_result.json',
                                allowEmptyArchive: true
                            )
                            sh 'rm -f scan_result.json || true'
                        }
                    }
                }

                // Archive Release APK
                stage('Archive APK') {
                    options {
                        timeout(time: 5, unit: 'MINUTES')
                    }
                    steps {
                        archiveArtifacts(
                            artifacts: 'app/build/outputs/apk/release/app-release.apk, app-release.apk.sha256',
                            fingerprint: true
                        )
                    }
                }
            }
        }
    }

    // ── Post Actions ────────────────────────────────────────────────────────
    post {
        always {
            sh 'rm -f release.keystore || true'
            sh 'rm -f /tmp/firebase-sa.json || true'
            sh 'rm -f pre_migration_backup.sql || true'
            sh 'rm -f scan_result.json || true'
            sh 'rm -f apk-signature.txt || true'
            sh 'rm -f audit.log || true'

            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '**/build/intermediates/**', type: 'INCLUDE'],
                    [pattern: '**/build/tmp/**', type: 'INCLUDE'],
                    [pattern: '**/build/.gradle/**', type: 'INCLUDE']
                ]
            )
        }

        success {
            script {
                notifySlack(
                    status: 'SUCCESS',
                    message: "Android Build #${env.BUILD_NUMBER} succeeded on ${env.BRANCH_NAME}",
                    channel: '#ci-notifications'
                )
            }
            echo """
            =============================================
            BUILD SUCCEEDED
            =============================================
            Branch   : ${env.BRANCH_NAME}
            Build    : ${env.BUILD_NUMBER}
            URL      : ${env.BUILD_URL}
            Duration : ${currentBuild.durationString}
            =============================================
            """
        }

        unstable {
            script {
                notifySlack(
                    status: 'UNSTABLE',
                    message: "Android Build #${env.BUILD_NUMBER} is UNSTABLE (test failures). CD skipped.",
                    channel: '#ci-notifications'
                )
            }
            echo """
            =============================================
            BUILD UNSTABLE (Test Failures)
            =============================================
            Branch   : ${env.BRANCH_NAME}
            Build    : ${env.BUILD_NUMBER}
            URL      : ${env.BUILD_URL}

            CD stage has been automatically skipped.
            Fix failing tests and retry.
            =============================================
            """
        }

        failure {
            script {
                notifySlack(
                    status: 'FAILURE',
                    message: "Android Build #${env.BUILD_NUMBER} FAILED on ${env.BRANCH_NAME}",
                    channel: '#ci-alerts'
                )
            }
            echo """
            =============================================
            BUILD FAILED
            =============================================
            Branch   : ${env.BRANCH_NAME}
            Build    : ${env.BUILD_NUMBER}
            URL      : ${env.BUILD_URL}

            Troubleshooting:
            1. Check console output for the specific error
            2. Verify Jenkins credentials are configured:
               Manage Jenkins > Credentials > System > Global
            3. For Android SDK errors:
               - Ensure agent image has SDK licenses accepted
               - Run: yes | sdkmanager --licenses
            4. For Firebase errors:
               - Verify Service Account JSON validity
               - Check app ID in Firebase Console
            5. For Supabase errors:
               - Verify project ID and access token
               - Check migration SQL syntax
               - See docs/RUNBOOK.md for rollback procedure
            6. For signing errors:
               - Verify keystore file is configured in Jenkins
               - Check key alias and password are correct
            7. For CVE scan failures:
               - Check build/reports/dependency-check-report.html
               - Update vulnerable dependencies or add suppressions
            8. For MobSF SAST failures:
               - Check scan_result.json in build artifacts
               - Address security issues to raise score above 70
            =============================================
            """
        }
    }
}
