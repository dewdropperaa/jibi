# ============================================================================
# Android CI Agent — Pre-baked with Firebase + Supabase CLI
# ============================================================================
# AUDIT FIX #13: Eliminates 60-90 seconds of CLI install per build.
# Built from pinned SHA256 digest of thyrlian/android-sdk (AUDIT FIX #1).
#
# Publish (no local Docker required): push to main/develop or run workflow
# "Build CI Agent Image" in GitHub Actions. Image: ghcr.io/<owner>/android-ci-agent
# ============================================================================
FROM thyrlian/android-sdk@sha256:bb9ed3686968550d927228777bca787dd7913e679f1e73e85525ba0094ea170d

# AUDIT FIX #13: Pre-install Firebase CLI and Supabase CLI at image build time.
# Base image apt nodejs/npm is unreliable; install Node from official tarball instead.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl xz-utils && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz \
      | tar -xJ -C /usr/local --strip-components=1 && \
    npm install -g firebase-tools@13.10.0 && \
    curl -fsSL https://github.com/supabase/cli/releases/download/v2.98.2/supabase_linux_amd64.tar.gz \
      | tar -xz -C /usr/local/bin supabase

# Ensure uid 1000 is named "jenkins" so pod runAsUser:1000 matches Jenkinsfile
# Gradle cache mount at /home/jenkins/.gradle.
RUN set -eux; \
    if getent passwd jenkins >/dev/null; then exit 0; fi; \
    if getent passwd 1000 >/dev/null; then \
      OLD=$(getent passwd 1000 | cut -d: -f1); \
      usermod -l jenkins -d /home/jenkins -m "$OLD"; \
    else \
      groupadd -f -g 1000 jenkins; \
      useradd -u 1000 -g 1000 -m -s /bin/bash jenkins; \
    fi

# AUDIT FIX #6: Pod Security Standards — run as non-root user
USER jenkins
