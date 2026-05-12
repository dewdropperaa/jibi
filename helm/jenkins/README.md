# Jenkins Helm Chart

Production-hardened Helm chart for deploying Jenkins CI/CD server on Kubernetes,
configured for Android CI/CD pipelines with security best practices.

## Prerequisites

- Kubernetes >= 1.25
- Helm >= 3.12
- cert-manager installed (for TLS certificates)
- nginx ingress controller installed
- PersistentVolume provisioner available (AWS EBS, Azure Disk, or GCE PD)

## Installation

### Install cert-manager (if not already installed)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s
```

### Deploy the Let's Encrypt ClusterIssuer

```bash
kubectl apply -f k8s/cert-manager-issuer.yaml
```

### Install Jenkins

```bash
helm install jenkins ./helm/jenkins \
  -n jenkins \
  --create-namespace
```

### Install with custom values

```bash
helm install jenkins ./helm/jenkins \
  -n jenkins \
  --create-namespace \
  --set ingress.host=ci.example.com \
  --set image.tag=2.452.2-lts-jdk17-alpine \
  --set persistence.size=20Gi
```

## Upgrade

```bash
helm upgrade jenkins ./helm/jenkins \
  -n jenkins \
  --set image.tag=2.462.1-lts-jdk17-alpine
```

To see what changes will be applied before upgrading:

```bash
helm diff upgrade jenkins ./helm/jenkins -n jenkins
```

## Uninstall

```bash
helm uninstall jenkins -n jenkins
```

Note: PVCs are retained after uninstall (reclaimPolicy: Retain) to prevent
accidental data loss. Delete them manually if you want to remove all data:

```bash
kubectl delete pvc -n jenkins -l app.kubernetes.io/managed-by=Helm
```

## Configuration

See [values.yaml](values.yaml) for the full list of configurable parameters.

### Key configuration options

| Parameter | Description | Default |
|---|---|---|
| `image.repository` | Jenkins container image | `jenkins/jenkins` |
| `image.tag` | Image tag (LTS recommended) | `2.452.2-lts-jdk17-alpine` |
| `image.digest` | SHA256 digest for supply chain security | *(pinned)* |
| `resources.requests.cpu` | CPU request | `750m` |
| `resources.requests.memory` | Memory request | `1536Mi` |
| `resources.limits.cpu` | CPU limit | `2` |
| `resources.limits.memory` | Memory limit | `4Gi` |
| `persistence.size` | Jenkins home PVC size | `10Gi` |
| `persistence.storageClass` | Storage class for PVC | `gp3` |
| `replicaCount` | Number of Jenkins replicas | `1` |
| `ingress.host` | Ingress hostname | `jenkins.example.com` |
| `ingress.tls.secretName` | TLS secret name | `jenkins-tls` |
| `jenkins.adminUser` | Admin username (from secret) | `admin` |
| `jenkins.adminPasswordSecret` | Secret containing admin credentials | `jenkins-admin-password` |

## Security Features

- Runs as non-root user (UID 1000)
- Privilege escalation disabled
- All Linux capabilities dropped
- Seccomp profile set to RuntimeDefault
- Network policies enforce zero-trust networking
- RBAC scoped to jenkins namespace only
- No cluster-wide secrets access
- Image pinned to SHA256 digest
- TLS enforced via cert-manager + Let's Encrypt
- Pod Disruption Budget for graceful node maintenance

## Backup

Daily automated backups are handled by the Jenkins backup CronJob:

```bash
kubectl get cronjob jenkins-backup -n jenkins
```

Manual backup:

```bash
kubectl create job manual-backup --from=cronjob/jenkins-backup -n jenkins
```

See `scripts/backup_jenkins.sh` for the backup implementation.

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n jenkins -l app.kubernetes.io/name=jenkins
```

### View logs

```bash
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins -f
```

### Check PVC status

```bash
kubectl get pvc -n jenkins
```

### Debug startup issues

```bash
kubectl describe pod -n jenkins -l app.kubernetes.io/name=jenkins
```

### Access Jenkins UI locally

```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

Then open http://localhost:8080

### Retrieve initial admin password

```bash
kubectl exec -n jenkins deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```
