plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.ktlint) apply false
    alias(libs.plugins.detekt) apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
    id("org.owasp.dependencycheck") version "9.0.9"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    format = "ALL"
    outputDirectory = "build/reports"
    suppressionFile = "config/dependency-check-suppressions.xml"
}
