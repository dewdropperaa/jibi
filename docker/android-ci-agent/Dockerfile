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
FROM thyrlian/android-sdk@sha256:bb9ed3686968550d927228777bca787dd7913e679f1e73e85525ba0094ea170d

# AUDIT FIX #13: Pre-install Firebase CLI and Supabase CLI at image build time
RUN npm install -g firebase-tools@13.10.0 && \
    curl -fsSL https://github.com/supabase/cli/releases/download/v1.223.4/supabase_1.223.4_linux_amd64.tar.gz | tar xz -C /usr/local/bin supabase

# AUDIT FIX #6: Pod Security Standards — run as non-root user
USER jenkins
