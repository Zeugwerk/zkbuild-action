#!/usr/bin/env bash

# ─── Vars ────────────────────────────────────────────────────────────────────────
SCM=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY
SHA="$GITHUB_SHA"
BRANCH=$GITHUB_HEAD_REF
ARTIFACT_NAME="${14:-${ARTIFACT_NAME:-artifact.zip}}"

if [ "$BRANCH" == "" ]; then
    BRANCH=$(echo $GITHUB_REF | sed 's/refs\/heads\///');
fi;

if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
  SHA=$(jq -r .pull_request.head.sha "$GITHUB_EVENT_PATH")
fi


# ─── Helpers ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m' 
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# info "some message"  — blue, for general progress updates
info() {
  echo -e "${BLUE}INFO:${NC} $*"
}

# success "some message"  — green, for successful completion
success() {
  echo -e "${GREEN}SUCCESS:${NC} $*"
}

# warn "some message"  — yellow, non-fatal warning
warn() {
  echo -e "${YELLOW}WARNING:${NC} $*"
}

# fail "some message"  — red, prints message then exits with code 1
fail() {
  echo -e "${RED}ERROR:${NC} $*" >&2
  exit 1
}

# debug "some message"  — only prints when DEBUG=true is set
debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    echo -e "DEBUG: $*"
  fi
}

# ─── Login ─────────────────────────────────────────────────────────────────────
info "Logging in to Zeugwerk CI/CD service..."
curl -s --show-error -N \
    -H "Accept: text/x-shell" \
    -F "username=$1" \
    -F "password=$2" \
    https://api.zeugwerk.dev/index.php/login > response 2>&1

status="$(tail -n1 response)"
bearer_token="$(tail -n2 response | head -n1 | cut -d '=' -f2)"
[[ "$status" != *"HTTP/1.1 200"* ]] && fail "Login failed! Check your USERNAME and PASSWORD."
success "Login successful."

# ─── Logout (runs on any exit) ─────────────────────────────────────────────────
logout() {
    info "Logging out..."
    curl -s --show-error -N \
        -H "Authorization: Bearer $bearer_token" \
        https://api.zeugwerk.dev/index.php/logout 
}
trap logout EXIT

# ─── Request build ─────────────────────────────────────────────────────────────
info "Requesting build..."
curl -s --show-error -N \
    -H "Authorization: Bearer $bearer_token" \
    -F "scm=$SCM" \
    -F "sha=$SHA" \
    -F "branch=$BRANCH" \
    -F "tcversion=$3" \
    -F "working-directory=$4" \
    -F "version=$5" \
    -F "skip-build=$6" \
    -F "skip-test=$7" \
    -F "variant-build=$8" \
    -F "variant-test=$9" \
    -F "static-analysis=${10}" \
    -F "installer=${11}" \
    -F "platform=${12}" \
    -F "force-checks=${13}" \
    -F "installer-name=${15}" \
    -F "async=true" \
    -F "log-stream=true" \
    https://api.zeugwerk.dev/index.php/build > response 2>&1

status="$(tail -n1 response)"
token="$(tail -n2 response | head -n1 | cut -d '=' -f2)"
head -n -4 response
[[ "$status" != *"HTTP/1.1 203"* ]] && fail "Build could not be queued!"

# ─── Poll for result ───────────────────────────────────────────────────────────
while [[ $status == *"HTTP/1.1 203"* ]]; do
    sleep 5

    curl -s --show-error -N \
        -H "Authorization: Bearer $bearer_token" \
        -F "async=true" \
        -F "log-stream=true" \
        -F "token=$token" \
        https://api.zeugwerk.dev/index.php/build > response 2>&1

    status="$(tail -n1 response)"
    artifact="$(tail -n2 response | head -n1 | cut -d '=' -f2)"

    tail -n +14 response | head -n -2

    if [[ "$status" != *"HTTP/1.1 201"* ]] && \
       [[ "$status" != *"HTTP/1.1 202"* ]] && \
       [[ "$status" != *"HTTP/1.1 203"* ]]; then
        fail "Build unsuccessful!"
    fi

    if [[ "$status" = *"HTTP/1.1 201"* ]]; then
        success "Build completed successfully (no artifact)."
        exit 0
    fi

    if [[ "$status" = *"HTTP/1.1 202"* ]]; then
        success "Build completed successfully."

        info "Downloading artifact from $artifact ..."
        curl --retry 3 --retry-delay 5 -u "$1:$2" -s -o "$ARTIFACT_NAME" "$artifact"
        [[ $? -ne 0 ]] && fail "Failed to download artifact from $artifact"
        success "Artifact downloaded to $ARTIFACT_NAME."

        info "Extracting artifact..."
        unzip -q -o "$ARTIFACT_NAME"
        UNZIP_STATUS=$?
        [[ $UNZIP_STATUS -gt 1 ]] && fail "Artifact extraction failed (exit code $UNZIP_STATUS)."
        success "Artifact extracted to archive/."

        # useful for bitbucket to make the pipeline fail if tests fail
        # if [ "$CHECK_TESTS" -eq 1 ]; then
        #     info "Collecting test results..."
        #     mkdir -p test-results
        #     find archive/tests -name "*.xml" -exec cp {} test-results/ \;
        #     grep -rqE '(failures|errors)="[1-9]' test-results/ && fail "Test failures detected in results."
        #     success "All tests passed."
        # fi

        exit 0
    fi
done

