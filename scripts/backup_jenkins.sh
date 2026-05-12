#!/bin/bash
# ============================================================================
# Jenkins PVC Backup Script
# ============================================================================
# Production-grade backup of Jenkins home directory to cloud storage.
#
# Purpose:
# - Backup /var/jenkins_home PVC daily (configs, jobs, credentials, build history)
# - Store backups to AWS S3, GCS, or Azure Blob Storage
# - Encrypt backups with GPG before upload
# - Implement retention policy (keep last 30 backups)
# - Verify backup integrity
# - Send Slack notification on success/failure
#
# Prerequisites:
# - kubectl configured with access to jenkins cluster
# - aws-cli (for S3) or gsutil (for GCS) or az-cli (for Azure)
# - gpg (for encryption)
# - jq (for JSON parsing)
#
# Usage:
#   ./scripts/backup_jenkins.sh
#
# Environment Variables:
#   BACKUP_DESTINATION  — Destination prefix: s3://, gs://, or az://
#   GPG_KEY_ID          — GPG key ID for encryption
#   SLACK_WEBHOOK_URL   — Slack webhook URL for notifications
#   JENKINS_NAMESPACE   — Kubernetes namespace (default: jenkins)
#   PVC_NAME            — PVC name to backup (default: jenkins-home-pvc)
#   RETENTION_COUNT     — Number of backups to retain (default: 30)
#
# Schedule via cron:
#   # Run daily at 2AM: 0 2 * * *
#   0 2 * * * /path/to/scripts/backup_jenkins.sh >> /var/log/jenkins-backup.log 2>&1
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
PVC_NAME="${PVC_NAME:-jenkins-home-pvc}"
BACKUP_DEST="${BACKUP_DESTINATION:-s3://my-backups/jenkins}"
GPG_KEY_ID="${GPG_KEY_ID:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
RETENTION_COUNT="${RETENTION_COUNT:-30}"
BACKUP_POD_NAME="jenkins-backup-$$"
LOG_FILE="/var/log/jenkins-backup.log"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
BACKUP_NAME="jenkins-${TIMESTAMP}.tar.gz"
ENCRYPTED_BACKUP_NAME="${BACKUP_NAME}.gpg"
TEMP_DIR=""

# Color output for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date -u +'%Y-%m-%d %H:%M:%S UTC') - $1" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date -u +'%Y-%m-%d %H:%M:%S UTC') - $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date -u +'%Y-%m-%d %H:%M:%S UTC') - $1" | tee -a "${LOG_FILE}"
}

# ============================================================================
# SLACK NOTIFICATION
# ============================================================================

send_slack_notification() {
    local status=$1
    local message=$2

    if [ -z "${SLACK_WEBHOOK_URL}" ]; then
        log_warn "SLACK_WEBHOOK_URL not set. Skipping Slack notification."
        return 0
    fi

    local color
    if [ "${status}" = "success" ]; then
        color="good"
    else
        color="danger"
    fi

    local payload
    payload=$(cat <<PAYLOAD
{
    "attachments": [
        {
            "color": "${color}",
            "title": "Jenkins Backup ${status^}",
            "text": "${message}",
            "footer": "Backup script | $(date -u +'%Y-%m-%d %H:%M:%S UTC')",
            "ts": $(date +%s)
        }
    ]
}
PAYLOAD
)

    if ! curl -s -X POST -H 'Content-type: application/json' \
        --data "${payload}" "${SLACK_WEBHOOK_URL}" > /dev/null 2>&1; then
        log_warn "Failed to send Slack notification."
        return 1
    fi

    log_info "Slack notification sent: ${status}"
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_prerequisites() {
    log_info "Validating prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        send_slack_notification "failure" "Backup failed: kubectl not found"
        exit 1
    fi

    if ! command -v tar &> /dev/null; then
        log_error "tar not found. Please install tar."
        send_slack_notification "failure" "Backup failed: tar not found"
        exit 1
    fi

    if [ -n "${GPG_KEY_ID}" ] && ! command -v gpg &> /dev/null; then
        log_error "GPG_KEY_ID is set but gpg not found. Please install gpg."
        send_slack_notification "failure" "Backup failed: gpg not found (GPG_KEY_ID is set)"
        exit 1
    fi

    if [[ "${BACKUP_DEST}" =~ ^s3:// ]]; then
        if ! command -v aws &> /dev/null; then
            log_error "BACKUP_DESTINATION is S3 but aws-cli not found."
            send_slack_notification "failure" "Backup failed: aws-cli not found for S3 destination"
            exit 1
        fi
    elif [[ "${BACKUP_DEST}" =~ ^gs:// ]]; then
        if ! command -v gsutil &> /dev/null; then
            log_error "BACKUP_DESTINATION is GCS but gsutil not found."
            send_slack_notification "failure" "Backup failed: gsutil not found for GCS destination"
            exit 1
        fi
    elif [[ "${BACKUP_DEST}" =~ ^az:// ]] || [[ "${BACKUP_DEST}" =~ https://.*\.blob\.core\.windows\.net ]]; then
        if ! command -v az &> /dev/null; then
            log_error "BACKUP_DESTINATION is Azure but az-cli not found."
            send_slack_notification "failure" "Backup failed: az-cli not found for Azure destination"
            exit 1
        fi
    else
        log_warn "BACKUP_DESTINATION does not match s3://, gs://, or az://. Using local filesystem."
    fi

    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        log_error "Cannot access namespace '${NAMESPACE}'. Verify kubectl context."
        send_slack_notification "failure" "Backup failed: Cannot access namespace '${NAMESPACE}'"
        exit 1
    fi

    if ! kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}" &> /dev/null; then
        log_error "PVC '${PVC_NAME}' not found in namespace '${NAMESPACE}'."
        send_slack_notification "failure" "Backup failed: PVC '${PVC_NAME}' not found"
        exit 1
    fi

    log_info "Prerequisites validation passed"
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

perform_backup() {
    log_info "Starting backup of PVC '${PVC_NAME}'..."

    local jenkins_pod
    jenkins_pod=$(kubectl get pods -n "${NAMESPACE}" -l app=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "${jenkins_pod}" ]; then
        log_error "No Jenkins controller pod found. Cannot backup."
        send_slack_notification "failure" "Backup failed: No Jenkins pod found"
        exit 1
    fi

    log_info "Using Jenkins pod: ${jenkins_pod}"

    TEMP_DIR=$(mktemp -d)
    trap "rm -rf ${TEMP_DIR}" EXIT

    log_info "Tarring /var/jenkins_home from pod..."
    if ! kubectl exec "${jenkins_pod}" -n "${NAMESPACE}" -- \
        tar czf "/tmp/${BACKUP_NAME}" -C /var/jenkins_home . 2>&1; then
        log_error "Failed to create backup archive in pod."
        send_slack_notification "failure" "Backup failed: Could not create archive in pod"
        exit 1
    fi

    log_info "Copying backup from pod to local: ${TEMP_DIR}/"
    if ! kubectl cp "${NAMESPACE}/${jenkins_pod}:/tmp/${BACKUP_NAME}" \
        "${TEMP_DIR}/${BACKUP_NAME}" 2>&1; then
        log_error "Failed to copy backup from pod."
        send_slack_notification "failure" "Backup failed: Could not copy backup from pod"
        exit 1
    fi

    kubectl exec "${jenkins_pod}" -n "${NAMESPACE}" -- rm -f "/tmp/${BACKUP_NAME}" 2>/dev/null || true

    if ! tar tzf "${TEMP_DIR}/${BACKUP_NAME}" > /dev/null 2>&1; then
        log_error "Backup archive integrity check failed."
        send_slack_notification "failure" "Backup failed: Archive integrity check failed"
        exit 1
    fi

    local backup_size
    backup_size=$(du -h "${TEMP_DIR}/${BACKUP_NAME}" | cut -f1)
    log_info "Backup created and verified. Size: ${backup_size}"

    echo "${TEMP_DIR}/${BACKUP_NAME}"
}

encrypt_backup() {
    local backup_file=$1

    if [ -z "${GPG_KEY_ID}" ]; then
        log_warn "GPG_KEY_ID not set. Skipping encryption."
        echo "${backup_file}"
        return 0
    fi

    log_info "Encrypting backup with GPG key: ${GPG_KEY_ID}..."

    if ! gpg --batch --yes --trust-model always \
        --recipient "${GPG_KEY_ID}" \
        --output "${backup_file}.gpg" \
        --encrypt "${backup_file}" 2>&1; then
        log_error "GPG encryption failed."
        send_slack_notification "failure" "Backup failed: GPG encryption failed"
        exit 1
    fi

    rm -f "${backup_file}"
    log_info "Backup encrypted successfully."

    echo "${backup_file}.gpg"
}

upload_backup() {
    local backup_file=$1
    local upload_name
    upload_name=$(basename "${backup_file}")

    log_info "Uploading backup to ${BACKUP_DEST}..."

    if [[ "${BACKUP_DEST}" =~ ^s3:// ]]; then
        log_info "Uploading to AWS S3..."
        if ! aws s3 cp "${backup_file}" "${BACKUP_DEST}/${upload_name}" \
            --storage-class STANDARD_IA \
            --metadata "timestamp=${TIMESTAMP},encrypted=${GPG_KEY_ID:+yes}" 2>&1; then
            log_error "S3 upload failed."
            send_slack_notification "failure" "Backup failed: S3 upload failed"
            exit 1
        fi
    elif [[ "${BACKUP_DEST}" =~ ^gs:// ]]; then
        log_info "Uploading to Google Cloud Storage..."
        if ! gsutil -m cp "${backup_file}" "${BACKUP_DEST}/${upload_name}" 2>&1; then
            log_error "GCS upload failed."
            send_slack_notification "failure" "Backup failed: GCS upload failed"
            exit 1
        fi
    elif [[ "${BACKUP_DEST}" =~ ^az:// ]] || [[ "${BACKUP_DEST}" =~ https://.*\.blob\.core\.windows\.net ]]; then
        log_info "Uploading to Azure Blob Storage..."
        local container_name
        container_name=$(echo "${BACKUP_DEST}" | sed 's|az://||; s|https://.*\.blob\.core\.windows\.net/||; s|/.*||')
        if ! az storage blob upload \
            --container-name "${container_name}" \
            --file "${backup_file}" \
            --name "${upload_name}" \
            --metadata "timestamp=${TIMESTAMP}" 2>&1; then
            log_error "Azure upload failed."
            send_slack_notification "failure" "Backup failed: Azure upload failed"
            exit 1
        fi
    else
        log_info "Copying to local destination: ${BACKUP_DEST}/"
        mkdir -p "${BACKUP_DEST}"
        if ! cp "${backup_file}" "${BACKUP_DEST}/${upload_name}"; then
            log_error "Local copy failed."
            send_slack_notification "failure" "Backup failed: Local copy failed"
            exit 1
        fi
    fi

    log_info "Backup uploaded successfully"
}

cleanup_old_backups() {
    log_info "Cleaning up old backups. Retaining last ${RETENTION_COUNT} backups..."

    if [[ "${BACKUP_DEST}" =~ ^s3:// ]]; then
        local old_backups
        old_backups=$(aws s3 ls "${BACKUP_DEST}/" | grep "jenkins-.*\.tar\.gz" | awk '{print $4}' | sort | head -n -"${RETENTION_COUNT}")
        if [ -n "${old_backups}" ]; then
            echo "${old_backups}" | while read -r backup; do
                log_warn "Deleting old S3 backup: ${backup}"
                aws s3 rm "${BACKUP_DEST}/${backup}" 2>/dev/null || true
            done
        fi
    elif [[ "${BACKUP_DEST}" =~ ^gs:// ]]; then
        local old_backups
        old_backups=$(gsutil ls "${BACKUP_DEST}/jenkins-*.tar.gz*" 2>/dev/null | sort | head -n -"${RETENTION_COUNT}")
        if [ -n "${old_backups}" ]; then
            echo "${old_backups}" | while read -r backup; do
                log_warn "Deleting old GCS backup: ${backup}"
                gsutil rm "${backup}" 2>/dev/null || true
            done
        fi
    elif [[ "${BACKUP_DEST}" =~ ^az:// ]] || [[ "${BACKUP_DEST}" =~ https://.*\.blob\.core\.windows\.net ]]; then
        local container_name
        container_name=$(echo "${BACKUP_DEST}" | sed 's|az://||; s|https://.*\.blob\.core\.windows\.net/||; s|/.*||')
        local old_backups
        old_backups=$(az storage blob list \
            --container-name "${container_name}" \
            --query "[?contains(name, 'jenkins-')].[name]" \
            -o tsv 2>/dev/null | sort | head -n -"${RETENTION_COUNT}")
        if [ -n "${old_backups}" ]; then
            echo "${old_backups}" | while read -r backup; do
                log_warn "Deleting old Azure backup: ${backup}"
                az storage blob delete --container-name "${container_name}" --name "${backup}" 2>/dev/null || true
            done
        fi
    else
        find "${BACKUP_DEST}" -name "jenkins-*.tar.gz*" -type f | sort | head -n -"${RETENTION_COUNT}" | while read -r backup; do
            log_warn "Deleting old local backup: ${backup}"
            rm -f "${backup}"
        done
    fi

    log_info "Cleanup completed"
}

# ============================================================================
# HEALTH CHECK
# ============================================================================

verify_backup_accessibility() {
    log_info "Verifying backup accessibility..."

    if [[ "${BACKUP_DEST}" =~ ^s3:// ]]; then
        aws s3 ls "${BACKUP_DEST}/" --human-readable --page-size 5 2>/dev/null | tail -5
    elif [[ "${BACKUP_DEST}" =~ ^gs:// ]]; then
        gsutil ls -l "${BACKUP_DEST}/jenkins-*.tar.gz*" 2>/dev/null | tail -5
    elif [[ "${BACKUP_DEST}" =~ ^az:// ]] || [[ "${BACKUP_DEST}" =~ https://.*\.blob\.core\.windows\.net ]]; then
        local container_name
        container_name=$(echo "${BACKUP_DEST}" | sed 's|az://||; s|https://.*\.blob\.core\.windows\.net/||; s|/.*||')
        az storage blob list --container-name "${container_name}" --query "[].{name:name,size:properties.contentLength}" -o table 2>/dev/null | tail -5
    else
        ls -lh "${BACKUP_DEST}" 2>/dev/null | grep "jenkins-" | tail -5
    fi

    log_info "Backup verification completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "=========================================="
    log_info "Jenkins PVC Backup Started"
    log_info "=========================================="
    log_info "Namespace: ${NAMESPACE}"
    log_info "PVC: ${PVC_NAME}"
    log_info "Backup Destination: ${BACKUP_DEST}"
    log_info "Retention: Last ${RETENTION_COUNT} backups"
    log_info "GPG Encryption: ${GPG_KEY_ID:+Enabled (key: ${GPG_KEY_ID})}${GPG_KEY_ID:+:-Disabled}"
    log_info "=========================================="

    validate_prerequisites

    backup_file=$(perform_backup)

    upload_file=$(encrypt_backup "${backup_file}")

    upload_backup "${upload_file}"

    cleanup_old_backups

    verify_backup_accessibility

    local backup_size
    backup_size=$(du -h "${upload_file}" 2>/dev/null | cut -f1 || echo "unknown")

    log_info "=========================================="
    log_info "Jenkins PVC Backup Completed Successfully"
    log_info "Backup: $(basename "${upload_file}")"
    log_info "Size: ${backup_size}"
    log_info "Destination: ${BACKUP_DEST}"
    log_info "=========================================="

    send_slack_notification "success" \
        "Backup completed: $(basename "${upload_file}") (${backup_size}) uploaded to ${BACKUP_DEST}"
}

trap 'log_error "Backup failed with exit code $?"; send_slack_notification "failure" "Backup failed unexpectedly. Check logs at ${LOG_FILE}"' ERR

main "$@"
