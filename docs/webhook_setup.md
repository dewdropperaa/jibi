# GitHub Webhook Setup for Jenkins

This guide configures GitHub to send push events to Jenkins, triggering the CI/CD pipeline automatically when code is pushed to `main` or `develop`.

---

## Prerequisites

- Jenkins is running on Kubernetes (see `scripts/setup_jenkins_k8s.sh`)
- The **GitHub plugin** is installed in Jenkins
- You have admin access to the GitHub repository

---

## Step 1: Get the Jenkins URL

On your local Minikube setup, get the Jenkins URL:

```bash
# Get the externally accessible URL for Jenkins
minikube service jenkins -n jenkins --url
```

This returns something like: `http://192.168.49.2:30080`

For production clusters, use the LoadBalancer IP or Ingress hostname.

> **Important:** GitHub.com must be able to reach this URL. For local Minikube, you need a tunnel. See [Step 6](#step-6-expose-minikube-to-github-for-local-development) below.

---

## Step 2: Install Required Jenkins Plugins

1. Open Jenkins UI: `http://<JENKINS_URL>:30080`
2. Go to: **Manage Jenkins** → **Plugins** → **Available plugins**
3. Search and install these plugins (if not already installed):
   - **GitHub plugin** — enables GitHub webhook trigger
   - **GitHub Branch Source** — for multi-branch pipeline support
   - **Git plugin** — Git SCM integration
4. Restart Jenkins after installation

---

## Step 3: Create a Jenkins Pipeline Job

1. From the Jenkins dashboard, click **"New Item"**
2. Enter a name: `MyApplication`
3. Select **"Multibranch Pipeline"** and click **OK**
4. Under **Branch Sources**, click **"Add source"** → **GitHub**
5. Configure:
   - **Repository HTTPS URL**: `https://github.com/<owner>/MyApplication.git`
   - **Credentials**: Add GitHub Personal Access Token (PAT) if the repo is private
     - Kind: Username with password
     - Username: your GitHub username
     - Password: your GitHub PAT (with `repo` scope)
   - **Behaviors**: Add "Discover branches" (filter by name: `main|develop`)
6. Under **Build Configuration**:
   - Mode: **by Jenkinsfile**
   - Script Path: `Jenkinsfile`
7. Under **Scan Multibranch Pipeline Triggers**:
   - Check **"GitHub hook trigger for GITScm polling"** (this is auto-enabled with the GitHub plugin)
8. Click **Save**

---

## Step 4: Configure the Webhook in GitHub

1. Open your GitHub repository in a browser
2. Go to: **Settings** → **Webhooks** → **Add webhook**
3. Fill in the webhook form:

| Field           | Value                                                    |
|-----------------|----------------------------------------------------------|
| **Payload URL** | `http://<JENKINS_URL>:30080/github-webhook/`             |
| **Content type**| `application/json`                                       |
| **Secret**      | *(optional but recommended — see Step 5)*                |
| **SSL verification** | Disable for Minikube (enable for production)        |
| **Events**      | Select **"Just the push event"**                         |
| **Active**      | Checked                                                  |

> **Critical:** The Payload URL must end with `/github-webhook/` (trailing slash required). This is the endpoint registered by the Jenkins GitHub plugin.

4. Click **"Add webhook"**

---

## Step 5: Set a Webhook Secret (Recommended)

A webhook secret prevents spoofed requests from triggering builds.

### In GitHub:
1. When creating the webhook (Step 4), enter a random secret string in the **Secret** field
2. Example: generate one with `openssl rand -hex 20`

### In Jenkins:
1. Go to: **Manage Jenkins** → **System** (Configure System)
2. Scroll to **GitHub** → **GitHub Servers**
3. Click **"Add GitHub Server"**
4. Configure:
   - **Name**: `GitHub`
   - **API URL**: `https://api.github.com`
   - **Credentials**: Add a "Secret text" credential with your GitHub PAT
   - Check **"Manage hooks"** to let Jenkins auto-manage webhooks
5. Under **Advanced**, set the **Shared secret** to the same value used in GitHub
6. Click **Save**

---

## Step 6: Expose Minikube to GitHub (For Local Development)

GitHub.com cannot reach `192.168.49.2` directly. Use a tunnel for local testing:

### Option A: ngrok (Recommended for testing)

```bash
# Install ngrok: https://ngrok.com/download
ngrok http 192.168.49.2:30080
```

This gives you a public URL like `https://abc123.ngrok.io`. Use this as the webhook Payload URL:
```
https://abc123.ngrok.io/github-webhook/
```

### Option B: Minikube tunnel + port forward

```bash
# In one terminal — expose Minikube services
minikube tunnel

# In another terminal — forward to localhost
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

Then use `http://localhost:8080/github-webhook/` (still requires ngrok or similar to expose to GitHub).

### Option C: Deploy to a cloud Kubernetes cluster

For production, deploy Jenkins to GKE/EKS/AKS with an Ingress and a real domain name. The webhook URL becomes:
```
https://jenkins.yourdomain.com/github-webhook/
```

---

## Step 7: Test the Webhook

### From GitHub:
1. Go to: **Settings** → **Webhooks**
2. Click on your webhook
3. Scroll down to **"Recent Deliveries"**
4. Click **"Redeliver"** on the most recent ping, or push a test commit:

```bash
git checkout develop
echo "// webhook test" >> test.txt
git add test.txt
git commit -m "test: verify Jenkins webhook trigger"
git push origin develop
```

5. Check that a new build appears in Jenkins

### Verify in Jenkins:
1. Open the Jenkins dashboard
2. Go to your `MyApplication` job
3. You should see a new build triggered by the push
4. Click into the build to view console output

### Troubleshooting:

| Symptom                           | Fix                                                        |
|-----------------------------------|------------------------------------------------------------|
| Webhook shows 403 Forbidden       | CSRF protection — disable "Prevent Cross Site Request Forgery exploits" in Manage Jenkins → Security, or configure the crumb issuer to exclude `/github-webhook/` |
| Webhook shows 404 Not Found       | Ensure URL ends with `/github-webhook/` (trailing slash)   |
| Webhook shows "Connection timed out" | Jenkins not reachable — check ngrok/tunnel is running     |
| Build not triggered               | Ensure "GitHub hook trigger for GITScm polling" is enabled in the job configuration |
| Wrong branch builds               | Check branch filter in Multibranch Pipeline config         |

---

## Architecture Diagram

```
GitHub Repository
       │
       │  push event (webhook POST)
       ▼
   ngrok tunnel  ─────────────────────►  Minikube
   (local dev)                           NodePort :30080
                                              │
                                              ▼
                                     ┌─────────────────┐
                                     │  Jenkins Master  │
                                     │  (K8s Pod)       │
                                     └────────┬────────┘
                                              │
                                    Kubernetes Plugin
                                              │
                                     ┌────────▼────────┐
                                     │  Agent Pod       │
                                     │  (android-sdk)   │
                                     │  - CI / CD       │
                                     └─────────────────┘
```
