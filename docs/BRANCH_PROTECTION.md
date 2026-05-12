# Branch Protection Rules

## Overview

This document defines the branch protection rules for the `main` and `develop`
branches of the repository. These rules ensure code quality, security, and
compliance before changes are merged.

## GitHub Branch Protection Rules

### Protected Branches

- `main` — Production branch
- `develop` — Integration/development branch

### Rules for `main`

| Setting | Value | Rationale |
|---|---|---|
| Require a pull request before merging | Enabled | No direct pushes to production |
| Required approvals | 1 | At least one reviewer must approve |
| Dismiss stale pull request approvals on new commits | Enabled | Ensures reviews reflect latest code |
| Require review from Code Owners | Enabled | Domain experts must review relevant files |
| Require status checks to pass before merging | Enabled | CI pipeline must succeed |
| Required status check | `Jenkins CI` | Jenkins pipeline must pass |
| Require branches to be up to date before merging | Enabled | Prevents merge conflicts |
| Require signed commits | Enabled | Ensures commit authenticity |
| Include administrators | Enabled | No exceptions, even for admins |
| Allow force pushes | Disabled | Prevents history rewriting |
| Allow deletions | Disabled | Prevents accidental branch deletion |

### Rules for `develop`

| Setting | Value | Rationale |
|---|---|---|
| Require a pull request before merging | Enabled | All changes go through PR review |
| Required approvals | 1 | At least one reviewer must approve |
| Dismiss stale pull request approvals on new commits | Enabled | Ensures reviews reflect latest code |
| Require status checks to pass before merging | Enabled | CI pipeline must succeed |
| Required status check | `Jenkins CI` | Jenkins pipeline must pass |
| Require signed commits | Enabled | Ensures commit authenticity |
| Include administrators | Enabled | No exceptions |
| Allow force pushes | Disabled | Prevents history rewriting |
| Allow deletions | Disabled | Prevents accidental branch deletion |

## Configure via GitHub API

### Prerequisites

- Personal Access Token with `repo` scope
- Repository owner and name

### Set Variables

```bash
REPO_OWNER="your-org"
REPO_NAME="your-repo"
GITHUB_TOKEN="ghp_your_token_here"
```

### Configure `main` Branch Protection

```bash
curl -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/branches/main/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": ["Jenkins CI"]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": true,
      "required_approving_review_count": 1,
      "require_code_owner_reviews": true
    },
    "restrictions": null,
    "required_linear_history": false,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": false,
    "lock_branch": false,
    "allow_fork_syncing": false
  }'
```

### Configure Signed Commits Requirement for `main`

```bash
curl -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/branches/main/protection/required_signatures" \
  -d '{"enabled": true}'
```

### Configure `develop` Branch Protection

```bash
curl -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/branches/develop/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": ["Jenkins CI"]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": true,
      "required_approving_review_count": 1,
      "require_code_owner_reviews": false
    },
    "restrictions": null,
    "required_linear_history": false,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": false,
    "lock_branch": false,
    "allow_fork_syncing": false
  }'
```

### Configure Signed Commits Requirement for `develop`

```bash
curl -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/branches/develop/protection/required_signatures" \
  -d '{"enabled": true}'
```

### Verify Branch Protection Settings

```bash
curl -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/branches/main/protection" | jq '.'
```

## Configure via GitHub CLI

### Using `gh` CLI (alternative to curl)

```bash
# Set main branch protection
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO_OWNER}/${REPO_NAME}/branches/main/protection" \
  -f required_status_checks='{"strict":true,"contexts":["Jenkins CI"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews='{"dismiss_stale_reviews":true,"required_approving_review_count":1}' \
  -f allow_force_pushes=false \
  -f allow_deletions=false
```

## Terraform Configuration (Infrastructure as Code)

```hcl
resource "github_branch_protection" "main" {
  repository_id = github_repository.myapp.name
  pattern       = "main"

  enforce_admins       = true
  allows_deletions     = false
  allows_force_pushes  = false

  required_status_checks {
    strict   = true
    contexts = ["Jenkins CI"]
  }

  required_pull_request_reviews {
    dismiss_stale_reviews  = true
    required_approving_review_count = 1
    require_code_owner_reviews = true
  }
}

resource "github_branch_protection" "develop" {
  repository_id = github_repository.myapp.name
  pattern       = "develop"

  enforce_admins       = true
  allows_deletions     = false
  allows_force_pushes  = false

  required_status_checks {
    strict   = true
    contexts = ["Jenkins CI"]
  }

  required_pull_request_reviews {
    dismiss_stale_reviews  = true
    required_approving_review_count = 1
  }
}

resource "github_branch_protection_rule" "signed_commits_main" {
  repository_id = github_repository.myapp.name
  pattern       = "main"

  required_status_checks {
    strict   = true
    contexts = ["Jenkins CI"]
  }
}
```

## Commit Signing Setup

### Generate GPG Key (for developers)

```bash
gpg --full-generate-key
# Choose: RSA (sign only), 4096 bits, no expiry
# Enter your name and email (must match git config)
```

### Configure Git to Sign Commits

```bash
# List secret keys to find the key ID
gpg --list-secret-keys --keyid-format=long

# Configure git to use the key
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
git config --global gpg.program gpg
```

### Add GPG Key to GitHub

```bash
# Export the public key
gpg --armor --export <KEY_ID>
```

1. Go to GitHub → Settings → SSH and GPG keys
2. Click **New GPG key**
3. Paste the exported public key
4. Click **Add GPG key**

### Verify Signed Commits

```bash
git log --show-signature -1
```

Commits will show `Good signature` when properly signed.
