#!/usr/bin/env bash
# ============================================================================
# setup_jenkins_k8s.sh — Jenkins on Kubernetes Local Setup Script
# ============================================================================
# This script automates the deployment of Jenkins on a local Minikube cluster.
#
# What it does:
#   1. Checks that required tools are installed (minikube, kubectl)
#   2. Starts Minikube if not already running
#   3. Applies all Kubernetes manifests in the correct order
#   4. Waits for the Jenkins pod to be Ready
#   5. Prints the Jenkins UI URL and initial admin password
#   6. Lists required Jenkins plugins to install
#
# Usage:
#   chmod +x scripts/setup_jenkins_k8s.sh
#   ./scripts/setup_jenkins_k8s.sh
# ============================================================================

set -euo pipefail

# ── Color output helpers ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Resolve the k8s/ manifests directory relative to this script ─────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/../k8s"

if [ ! -d "$K8S_DIR" ]; then
    log_error "Kubernetes manifests directory not found: $K8S_DIR"
    log_error "Ensure the k8s/ folder exists at the repo root."
    exit 1
fi

# ============================================================================
# Step 1: Check prerequisites
# ============================================================================
log_info "Checking prerequisites..."

# Check minikube
if ! command -v minikube &> /dev/null; then
    log_error "minikube is not installed."
    log_error "Install it from: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi
log_success "minikube found: $(minikube version --short 2>/dev/null || minikube version | head -1)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed."
    log_error "Install it from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
log_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | head -1)"

# ============================================================================
# Step 2: Start Minikube if not running
# ============================================================================
log_info "Checking Minikube status..."

MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")

if [ "$MINIKUBE_STATUS" != "Running" ]; then
    log_warn "Minikube is not running. Starting Minikube..."
    log_info "Allocating 4 CPUs and 8GB memory for Jenkins workloads..."
    minikube start --cpus=4 --memory=8192 --driver=docker
    log_success "Minikube started successfully."
else
    log_success "Minikube is already running."
fi

# Verify the cluster is accessible
kubectl cluster-info > /dev/null 2>&1 || {
    log_error "Cannot connect to Kubernetes cluster. Check minikube status."
    exit 1
}
log_success "Kubernetes cluster is accessible."

# ============================================================================
# Step 3: Apply Kubernetes manifests in correct order
# ============================================================================
log_info "Applying Kubernetes manifests..."

# Order matters:
#   1. Namespace first (all other resources reference it)
#   2. ServiceAccount + RBAC (deployment references the SA)
#   3. PVC (deployment mounts it)
#   4. Deployment (references SA and PVC)
#   5. Service (exposes the deployment)

log_info "  [1/5] Creating namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"
log_success "  Namespace 'jenkins' created."

log_info "  [2/5] Creating ServiceAccount and RBAC..."
kubectl apply -f "$K8S_DIR/jenkins-sa.yaml"
log_success "  ServiceAccount and ClusterRoleBinding created."

log_info "  [3/5] Creating PersistentVolumeClaim..."
kubectl apply -f "$K8S_DIR/jenkins-pvc.yaml"
log_success "  PVC 'jenkins-home-pvc' created (10Gi)."

log_info "  [4/5] Creating Jenkins Deployment..."
kubectl apply -f "$K8S_DIR/jenkins-deployment.yaml"
log_success "  Deployment 'jenkins' created."

log_info "  [5/5] Creating Jenkins Service..."
kubectl apply -f "$K8S_DIR/jenkins-service.yaml"
log_success "  Service 'jenkins' created (NodePort 30080/30050)."

# ============================================================================
# Step 4: Wait for Jenkins pod to be Ready
# ============================================================================
log_info "Waiting for Jenkins pod to be Ready (this may take 2-5 minutes on first boot)..."

# Wait up to 5 minutes for the deployment to be available
if kubectl rollout status deployment/jenkins -n jenkins --timeout=300s; then
    log_success "Jenkins pod is Ready!"
else
    log_error "Jenkins pod did not become Ready within 5 minutes."
    log_error "Check pod status with: kubectl get pods -n jenkins"
    log_error "Check pod logs with:   kubectl logs -n jenkins -l app=jenkins"
    exit 1
fi

# ============================================================================
# Step 5: Print Jenkins UI URL
# ============================================================================
echo ""
echo "============================================================"
echo -e "${GREEN}  Jenkins is deployed and running!${NC}"
echo "============================================================"
echo ""

# Get the URL via minikube service
JENKINS_URL=$(minikube service jenkins -n jenkins --url 2>/dev/null | head -1 || echo "http://$(minikube ip):30080")
log_info "Jenkins UI URL: ${JENKINS_URL}"
echo ""

# ============================================================================
# Step 6: Print initial admin password
# ============================================================================
log_info "To get the initial admin password, run:"
echo ""
echo -e "  ${YELLOW}kubectl exec -n jenkins \$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword${NC}"
echo ""

# Try to retrieve it now (may fail if Jenkins is still initializing)
JENKINS_POD=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$JENKINS_POD" ]; then
    ADMIN_PASSWORD=$(kubectl exec -n jenkins "$JENKINS_POD" -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
    if [ -n "$ADMIN_PASSWORD" ]; then
        echo -e "  ${GREEN}Initial Admin Password: ${ADMIN_PASSWORD}${NC}"
        echo ""
    else
        log_warn "Password not yet available. Jenkins may still be initializing."
        log_warn "Wait a moment and run the command above."
    fi
fi

# ============================================================================
# Step 7: Print required Jenkins plugins
# ============================================================================
echo "============================================================"
echo -e "${BLUE}  Required Jenkins Plugins${NC}"
echo "============================================================"
echo ""
echo "  After logging in, go to: Manage Jenkins → Plugins → Available"
echo "  Search for and install the following plugins:"
echo ""
echo "  REQUIRED:"
echo "    - kubernetes              (Kubernetes plugin for dynamic agents)"
echo "    - git                     (Git SCM integration)"
echo "    - github                  (GitHub webhook integration)"
echo "    - workflow-aggregator     (Pipeline plugin suite)"
echo "    - credentials-binding     (Bind credentials in pipelines)"
echo "    - junit                   (JUnit test result reporting)"
echo ""
echo "  OPTIONAL (recommended):"
echo "    - android-lint            (Android Lint report integration)"
echo "    - timestamper             (Add timestamps to console output)"
echo "    - pipeline-stage-view     (Visual stage view for pipelines)"
echo ""
echo "============================================================"
echo ""

# ============================================================================
# Step 8: Print Kubernetes plugin configuration reminder
# ============================================================================
echo "============================================================"
echo -e "${BLUE}  Post-Install: Configure Kubernetes Plugin${NC}"
echo "============================================================"
echo ""
echo "  After installing plugins and restarting Jenkins:"
echo ""
echo "  1. Go to: Manage Jenkins → Clouds → New cloud → Kubernetes"
echo "  2. Configure:"
echo "     - Kubernetes URL: https://kubernetes.default.svc.cluster.local"
echo "     - Jenkins URL:    http://jenkins.jenkins.svc.cluster.local:8080"
echo "     - Jenkins tunnel: jenkins.jenkins.svc.cluster.local:50000"
echo "     - Namespace:      jenkins"
echo "  3. Test the connection (should show 'Connected to Kubernetes')"
echo "  4. Save"
echo ""
echo "  Then create your pipeline job — see docs/webhook_setup.md"
echo ""
echo "============================================================"
