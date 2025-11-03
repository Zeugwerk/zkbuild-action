#!/usr/bin/env bash
SCM=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY
SHA="$GITHUB_SHA"
BRANCH=$GITHUB_HEAD_REF

if [ "$BRANCH" == "" ]; then
    BRANCH=$(echo $GITHUB_REF | sed 's/refs\/heads\///');
fi;

if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
  SHA=$(jq -r .pull_request.head.sha "$GITHUB_EVENT_PATH")
fi

echo "Using commit SHA: $SHA"

echo "Login ..."
curl -s --show-error -N \
    -H "Accept: text/x-shell" \
    -F "username=$1" \
    -F "password=$2" \
    -F "method=zklogin" \
    https://zeugwerk.dev/api.php > response 2>&1

status="$(tail -n1 response)"
bearer_token="$(tail -n2 response | head -n1 | cut -d '=' -f2)"

# Status is not PENDING
if [[ "$status" != *"HTTP/1.1 200"* ]]; then
    echo -e "\n\nLogin failed!"
    exit 1
fi

echo "Requesting build ..."

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
    -F "method=zkbuild" \
    -F "async=true" \
    https://zeugwerk.dev/api.php > response 2>&1

status="$(tail -n1 response)"
token="$(tail -n2 response | head -n1 | cut -d '=' -f2)"

head -n -4 response

# Status is not PENDING
if [[ "$status" != *"HTTP/1.1 203"* ]]; then
    echo -e "\n\nBuild is not queued!"
    exit 1
fi

while [[ $status == *"HTTP/1.1 203"*   ]]; do

    curl -s --show-error -N \
        -H "Authorization: Bearer $bearer_token" \
        -F "method=zkbuild" \
        -F "async=true" \
        -F "token=$token" \
        https://zeugwerk.dev/api.php > response 2>&1

    status="$(tail -n1 response)"
    artifact="$(tail -n2 response | head -n1 | cut -d '=' -f2)"

    # Status is not SUCCESS and not UNSTABLE
    if [[ "$status" != *"HTTP/1.1 201"* ]] && [[ "$status" != *"HTTP/1.1 202"* ]] && [[ "$status" != *"HTTP/1.1 203"* ]]; then
        tail -n +14 response 
        echo -e "\n\nBuild unsuccessful!"
        exit 1
    fi

    # Build is done
    if [[ "$status" = *"HTTP/1.1 201"* ]]; then
       tail -n +14 response 
       exit 0
    fi

    # We got an artifact that we can extract
    if [[ "$status" = *"HTTP/1.1 202"* ]]; then
        tail -n +14 response 
        curl --retry 3 --retry-delay 5 -u "$1:$2" -s -o 'artifact.zip' $artifact
        if [[ $? -ne 0 ]]; then
            echo "Failed to download artifact from $artifact"
            exit 202
        fi
        
        # return code 0 means no errors
        # return code 1 means there was an error or warning, but processing was successful anyway
        unzip -q -o 'artifact.zip'
        echo -e "\n\nArtifacts extracted to archive/"
        if [[ $? -gt 1 ]]; then
            exit 202
        fi

        exit 0
    fi

    sleep 10
done

