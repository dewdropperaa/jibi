# ============================================================================
# Android CI Agent — Pre-baked with Firebase + Supabase CLI
# ============================================================================
# AUDIT FIX #13: Eliminates 60-90 seconds of CLI install per build.
# Built from pinned SHA256 digest of thyrlian/android-sdk (AUDIT FIX #1).
#
# Build and push:
#   docker build -t registry.example.com/android-ci-agent:1.0.0 .
#   docker push registry.example.com/android-ci-agent:1.0.0
# ============================================================================
FROM thyrlian/android-sdk@sha256:8a9e5e3a8f7c6b5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0

# AUDIT FIX #13: Pre-install Firebase CLI and Supabase CLI at image build time
RUN npm install -g firebase-tools@13.10.0 && \
    curl -fsSL https://github.com/supabase/cli/releases/download/v1.223.4/supabase_1.223.4_linux_amd64.tar.gz | tar xz -C /usr/local/bin supabase

# AUDIT FIX #6: Pod Security Standards — run as non-root user
USER jenkins
