#!/usr/bin/env bash

set -u

PASS_COUNT=0
TOTAL_CHECKS=13

pass() {
  local message="$1"
  echo "✅ PASS: ${message}"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  local message="$1"
  local fix="$2"
  echo "❌ FAIL: ${message}"
  echo "   Fix: ${fix}"
}

echo "=== Android CI/CD Pre-flight Pipeline Checks ==="
echo

# 1) gradlew executable
if [[ -x "./gradlew" ]]; then
  pass "gradlew is executable."
else
  fail "gradlew is not executable." "Run: chmod +x ./gradlew"
fi

# 2) ktlint plugin present
if rg -n 'org\.jlleitschuh\.gradle\.ktlint|ktlint' "build.gradle.kts" > /dev/null 2>&1; then
  pass "ktlint plugin/config detected in build.gradle.kts."
else
  fail "ktlint plugin/config not found in build.gradle.kts." "Add ktlint plugin (for example: id(\"org.jlleitschuh.gradle.ktlint\"))."
fi

# 3) detekt plugin present
if rg -n 'io\.gitlab\.arturbosch\.detekt|detekt' "build.gradle.kts" > /dev/null 2>&1; then
  pass "detekt plugin/config detected in build.gradle.kts."
else
  fail "detekt plugin/config not found in build.gradle.kts." "Add detekt plugin (for example: id(\"io.gitlab.arturbosch.detekt\"))."
fi

# 4) detekt.yml exists at root
if [[ -f "detekt.yml" ]]; then
  pass "detekt.yml exists at repository root."
else
  fail "detekt.yml is missing at repository root." "Create detekt.yml at the project root and commit it."
fi

# 5) release.keystore decodes from KEYSTORE_BASE64
KEYSTORE_READY=0
if [[ -n "${KEYSTORE_BASE64:-}" ]]; then
  if echo "${KEYSTORE_BASE64}" | base64 --decode > "release.keystore" 2>/dev/null; then
    pass "release.keystore decoded successfully from KEYSTORE_BASE64."
    KEYSTORE_READY=1
  else
    fail "Could not decode KEYSTORE_BASE64 into release.keystore." "Regenerate base64 from a valid keystore and export KEYSTORE_BASE64 again."
  fi
else
  fail "KEYSTORE_BASE64 environment variable is not set." "Export KEYSTORE_BASE64 before running this script."
fi

# 6) signing flags dry-run assembleRelease
if [[ "${KEYSTORE_READY}" -eq 1 && -n "${KEY_ALIAS:-}" && -n "${KEY_PASSWORD:-}" && -n "${STORE_PASSWORD:-}" ]]; then
  if ./gradlew assembleRelease --dry-run \
    -Pandroid.injected.signing.store.file="$(pwd)/release.keystore" \
    -Pandroid.injected.signing.store.password="${STORE_PASSWORD}" \
    -Pandroid.injected.signing.key.alias="${KEY_ALIAS}" \
    -Pandroid.injected.signing.key.password="${KEY_PASSWORD}" > /dev/null 2>&1; then
    pass "Signing configuration flags work with assembleRelease --dry-run."
  else
    fail "Signing dry-run assembleRelease failed." "Verify signing secrets (KEY_ALIAS, KEY_PASSWORD, STORE_PASSWORD) and Android signing config in Gradle."
  fi
else
  fail "Cannot run signing dry-run (missing keystore or signing env vars)." "Set KEYSTORE_BASE64, KEY_ALIAS, KEY_PASSWORD, and STORE_PASSWORD, then rerun."
fi

# 7) release APK output exists after real build
APK_PATH="app/build/outputs/apk/release/app-release.apk"
if [[ -f "${APK_PATH}" ]]; then
  pass "Release APK already exists at ${APK_PATH}."
else
  if [[ "${KEYSTORE_READY}" -eq 1 && -n "${KEY_ALIAS:-}" && -n "${KEY_PASSWORD:-}" && -n "${STORE_PASSWORD:-}" ]]; then
    if ./gradlew assembleRelease \
      -Pandroid.injected.signing.store.file="$(pwd)/release.keystore" \
      -Pandroid.injected.signing.store.password="${STORE_PASSWORD}" \
      -Pandroid.injected.signing.key.alias="${KEY_ALIAS}" \
      -Pandroid.injected.signing.key.password="${KEY_PASSWORD}" > /dev/null 2>&1 && [[ -f "${APK_PATH}" ]]; then
      pass "Real release build produced APK at ${APK_PATH}."
    else
      fail "Real release build did not produce ${APK_PATH}." "Run ./gradlew assembleRelease locally, resolve build/signing errors, and verify output path."
    fi
  else
    fail "Cannot validate APK output path (missing signing env vars/keystore)." "Set signing env vars and rerun this script to perform a real release build."
  fi
fi

# 8) Firebase CLI installed and authenticated
if command -v firebase > /dev/null 2>&1; then
  if firebase projects:list > /dev/null 2>&1; then
    pass "Firebase CLI is installed and authentication is valid."
  else
    fail "Firebase CLI is installed but not authenticated." "Run: firebase login (or firebase login:ci) and retry."
  fi
else
  fail "Firebase CLI is not installed." "Install with: npm install -g firebase-tools"
fi

# 9) FIREBASE_APP_ID and FIREBASE_TOKEN are set
if [[ -n "${FIREBASE_APP_ID:-}" && -n "${FIREBASE_TOKEN:-}" ]]; then
  pass "FIREBASE_APP_ID and FIREBASE_TOKEN are set."
else
  fail "FIREBASE_APP_ID and/or FIREBASE_TOKEN are missing." "Export both FIREBASE_APP_ID and FIREBASE_TOKEN before running CD checks."
fi

# 10) Supabase CLI installed
if command -v supabase > /dev/null 2>&1; then
  pass "Supabase CLI is installed."
else
  fail "Supabase CLI is not installed." "Install with: npm install -g supabase"
fi

# 11) supabase/migrations exists and is non-empty
if [[ -d "supabase/migrations" ]] && [[ -n "$(ls -A "supabase/migrations" 2>/dev/null)" ]]; then
  pass "supabase/migrations exists and is non-empty."
else
  fail "supabase/migrations is missing or empty." "Add and commit migration files under supabase/migrations."
fi

# 12) SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_ID are set
if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" && -n "${SUPABASE_PROJECT_ID:-}" ]]; then
  pass "SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_ID are set."
else
  fail "SUPABASE_ACCESS_TOKEN and/or SUPABASE_PROJECT_ID are missing." "Export both SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_ID."
fi

# 13) supabase link works
if command -v supabase > /dev/null 2>&1 && [[ -n "${SUPABASE_PROJECT_ID:-}" ]]; then
  if SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-}" supabase link --project-ref "${SUPABASE_PROJECT_ID}" > /dev/null 2>&1; then
    pass "supabase link succeeded."
  else
    fail "supabase link failed." "Verify SUPABASE_ACCESS_TOKEN, SUPABASE_PROJECT_ID, network access, and Supabase project permissions."
  fi
else
  fail "Cannot run supabase link check." "Install Supabase CLI and set SUPABASE_PROJECT_ID (and token) first."
fi

echo
echo "=== Summary ==="
echo "${PASS_COUNT}/${TOTAL_CHECKS} checks passed."

if [[ "${PASS_COUNT}" -ne "${TOTAL_CHECKS}" ]]; then
  exit 1
fi
