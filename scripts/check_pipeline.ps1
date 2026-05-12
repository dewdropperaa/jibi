$pass = 0
$fail = 0

function Check($label, $result, $fix) {
    if ($result) {
        Write-Host "PASS - $label" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "FAIL - $label" -ForegroundColor Red
        Write-Host "  FIX: $fix" -ForegroundColor Yellow
        $script:fail++
    }
}

Write-Host "`nRunning pipeline pre-flight checks...`n" -ForegroundColor Cyan

$gradleFile = if (Test-Path "app/build.gradle.kts") { "app/build.gradle.kts" } elseif (Test-Path "build.gradle.kts") { "build.gradle.kts" } else { "" }

Check "gradlew.bat exists" `
    (Test-Path "gradlew.bat") `
    "Make sure you're running this from the root of your Android project"

Check "ktlint plugin present in build.gradle.kts" `
    ($gradleFile -ne "" -and (Select-String -Path $gradleFile -Pattern "ktlint" -Quiet)) `
    "Add: id('org.jlleitschuh.gradle.ktlint') version '12.1.0' to your plugins block"

Check "detekt plugin present in build.gradle.kts" `
    ($gradleFile -ne "" -and (Select-String -Path $gradleFile -Pattern "detekt" -Quiet)) `
    "Add: id('io.gitlab.arturbosch.detekt') version '1.23.6' to your plugins block"

Check "detekt.yml exists at root" `
    (Test-Path "detekt.yml") `
    "Run: ./gradlew detektGenerateConfig to generate a default detekt.yml"

Check "KEYSTORE_BASE64 env var is set" `
    ($env:KEYSTORE_BASE64 -ne $null -and $env:KEYSTORE_BASE64 -ne "") `
    "Run: `$env:KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('your.keystore'))"

if ($env:KEYSTORE_BASE64) {
    try {
        $bytes = [Convert]::FromBase64String($env:KEYSTORE_BASE64)
        [IO.File]::WriteAllBytes("$env:TEMP\release.keystore", $bytes)
        $null = & keytool -list -keystore "$env:TEMP\release.keystore" -storepass "$env:STORE_PASSWORD" 2>&1
        Check "Keystore decodes and is valid" `
            ($LASTEXITCODE -eq 0) `
            "Check your KEYSTORE_BASE64 and STORE_PASSWORD env vars are correct"
        Remove-Item "$env:TEMP\release.keystore" -Force
    } catch {
        Check "Keystore decodes and is valid" $false "KEYSTORE_BASE64 is not valid base64"
    }
} else {
    Check "Keystore decodes and is valid" $false "Set KEYSTORE_BASE64 first (check #5)"
}

Check "Firebase CLI is installed" `
    ($null -ne (Get-Command firebase -ErrorAction SilentlyContinue)) `
    "Run: npm install -g firebase-tools"

Check "FIREBASE_APP_ID is set" `
    ($env:FIREBASE_APP_ID -ne $null -and $env:FIREBASE_APP_ID -ne "") `
    "Set it with: `$env:FIREBASE_APP_ID = '1:xxxxxxxxxx:android:xxxxxxxxxx'"

Check "FIREBASE_TOKEN is set" `
    ($env:FIREBASE_TOKEN -ne $null -and $env:FIREBASE_TOKEN -ne "") `
    "Run: firebase login:ci then set `$env:FIREBASE_TOKEN = 'your-token'"

Check "Supabase CLI is installed" `
    ($null -ne (Get-Command supabase -ErrorAction SilentlyContinue)) `
    "Install from: https://supabase.com/docs/guides/cli"

Check "supabase/migrations folder exists and has files" `
    ((Test-Path "supabase/migrations") -and ((Get-ChildItem "supabase/migrations").Count -gt 0)) `
    "Run locally: supabase init then supabase db pull then commit the supabase/ folder"

Check "SUPABASE_ACCESS_TOKEN is set" `
    ($env:SUPABASE_ACCESS_TOKEN -ne $null -and $env:SUPABASE_ACCESS_TOKEN -ne "") `
    "Get it from: supabase.com/dashboard/account/tokens then set `$env:SUPABASE_ACCESS_TOKEN = 'your-token'"

Check "SUPABASE_PROJECT_ID is set" `
    ($env:SUPABASE_PROJECT_ID -ne $null -and $env:SUPABASE_PROJECT_ID -ne "") `
    "Find it in your Supabase project URL then set `$env:SUPABASE_PROJECT_ID = 'your-project-ref'"

Check "Release APK output path exists" `
    (Test-Path "app/build/outputs/apk/release/app-release.apk") `
    "Run: .\gradlew.bat assembleRelease first then re-run this script"

$total = $pass + $fail
Write-Host "`n----------------------------------" -ForegroundColor Cyan
Write-Host "  $pass/$total checks passed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
if ($fail -gt 0) {
    Write-Host "  Fix the FAIL items above before pushing to main" -ForegroundColor Red
} else {
    Write-Host "  All checks passed - pipeline is ready" -ForegroundColor Green
}
Write-Host "----------------------------------`n" -ForegroundColor Cyan
