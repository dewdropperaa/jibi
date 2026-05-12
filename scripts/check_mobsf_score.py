#!/usr/bin/env python3
"""
MobSF Security Score Checker

Parses MobSF scan result JSON and fails the build if the security score
is below the specified threshold.

Usage:
    python3 check_mobsf_score.py <scan_result.json> <min_score>

Arguments:
    scan_result.json  Path to the MobSF scan result JSON file
    min_score         Minimum acceptable security score (0-100)

Exit codes:
    0  Security score meets or exceeds the threshold
    1  Security score is below the threshold (build fails)
    2  Invalid input or parsing error

Example Jenkinsfile usage:
    stage('SAST - MobSF') {
        steps {
            sh '''
                curl -F "file=@app/build/outputs/apk/release/app-release.apk" \\
                  -H "Authorization: ${MOBSF_API_KEY}" \\
                  https://your-mobsf-instance/api/v1/upload > scan_result.json
                python3 scripts/check_mobsf_score.py scan_result.json 70
            '''
        }
    }
"""

import json
import sys
import os


def parse_mobsf_result(filepath):
    """Parse the MobSF scan result JSON file and extract the security score."""
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    if "scan_results" in data:
        scan_results = data["scan_results"]
        if "files" in scan_results:
            files_data = scan_results["files"]
            if "android" in files_data:
                android_data = files_data["android"]
                if "score" in android_data:
                    return float(android_data["score"])

    if "security_score" in data:
        return float(data["security_score"])

    scores = []
    if "high" in data:
        scores.append(0)
    if "info" in data:
        pass

    if "meta" in data:
        meta = data["meta"]
        if "scores" in meta:
            scores_data = meta["scores"]
            if "secured" in scores_data:
                return float(scores_data["secured"])

    if "apk" in data:
        apk_data = data["apk"]
        if "score" in apk_data:
            return float(apk_data["score"])

    return None


def get_severity_breakdown(data):
    """Extract severity breakdown from scan results for reporting."""
    breakdown = {"high": 0, "medium": 0, "low": 0, "info": 0}

    if "scan_results" in data:
        scan_results = data["scan_results"]
        for category in ["manifest_analysis", "certificate_analysis",
                          "code_analysis", "file_analysis", "strings_analysis",
                          "niap_analysis", "permission_mapping",
                          "urls_domains", "email_found", "firebase"]:
            if category in scan_results:
                category_data = scan_results[category]
                if isinstance(category_data, list):
                    for item in category_data:
                        if isinstance(item, dict):
                            severity = item.get("severity", "").lower()
                            if severity in breakdown:
                                breakdown[severity] += 1

    return breakdown


def check_score(filepath, min_score):
    """Check if the MobSF security score meets the minimum threshold."""
    if not os.path.isfile(filepath):
        print(f"[ERROR] File not found: {filepath}")
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    score = parse_mobsf_result(data)

    if score is None:
        print("[ERROR] Could not extract security score from scan results.")
        print("[INFO] Expected one of: scan_results.files.android.score, security_score, meta.scores.secured, apk.score")
        return False

    breakdown = get_severity_breakdown(data)

    print("=" * 60)
    print("MobSF Security Analysis Report")
    print("=" * 60)
    print(f"  Security Score:   {score}/100")
    print(f"  Minimum Required: {min_score}/100")
    print("-" * 60)
    print("  Severity Breakdown:")
    print(f"    HIGH:   {breakdown['high']}")
    print(f"    MEDIUM: {breakdown['medium']}")
    print(f"    LOW:    {breakdown['low']}")
    print(f"    INFO:   {breakdown['info']}")
    print("=" * 60)

    if score >= min_score:
        print(f"[PASS] Security score ({score}) meets the minimum threshold ({min_score}).")
        return True
    else:
        print(f"[FAIL] Security score ({score}) is below the minimum threshold ({min_score}).")
        print(f"[FAIL] Build is being rejected due to insufficient security posture.")
        if breakdown['high'] > 0:
            print(f"[CRITICAL] {breakdown['high']} HIGH severity issues must be resolved before deployment.")
        if breakdown['medium'] > 0:
            print(f"[WARNING] {breakdown['medium']} MEDIUM severity issues should be reviewed.")
        return False


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <scan_result.json> <min_score>")
        sys.exit(2)

    filepath = sys.argv[1]
    try:
        min_score = float(sys.argv[2])
    except ValueError:
        print(f"[ERROR] Invalid minimum score: {sys.argv[2]}. Must be a number.")
        sys.exit(2)

    if not (0 <= min_score <= 100):
        print(f"[ERROR] Minimum score must be between 0 and 100. Got: {min_score}")
        sys.exit(2)

    passed = check_score(filepath, min_score)
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
