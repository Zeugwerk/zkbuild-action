#!/usr/bin/env bash

# Get the current branch name
BRANCH=$GITHUB_HEAD_REF
if [ "$BRANCH" == "" ]; then
    BRANCH=$(echo $GITHUB_REF | sed 's/refs\/heads\///');
fi;

echo "Requesting build ..."

curl -s --show-error -N \
    -F "scm=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY" \
    -F "sha=$GITHUB_SHA" \
    -F "branch=$BRANCH" \
    -F "username=$1" \
    -F "password=$2" \
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
        -F "method=zkbuild" \
        -F "username=$1" \
        -F "password=$2" \
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
        wget --user=$1 --password=$2 -q -O 'artifact.zip' $artifact
        if [[ $? -ne 0 ]]; then
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

