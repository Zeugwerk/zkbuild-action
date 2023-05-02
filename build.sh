#!/usr/bin/env bash

BITBUCKET_SERVER_URL=$BITBUCKET_GIT_HTTP_ORIGIN
BRANCH=$BITBUCKET_BRANCH

# Run a build
curl -s --show-error -N -G --data-urlencode "scm=$BITBUCKET_SERVER_URL" --data-urlencode "sha=$BITBUCKET_COMMIT" --data-urlencode "branch=$BRANCH" --data-urlencode "username=$1" --data-urlencode "password=$2" --data-urlencode "tcversion=$3" --data-urlencode "method=zkbuild" https://operations.zeugwerk.dev/api.php | tee response
status="$(tail -n1 response)"

# Status is not SUCCESS and not UNSTABLE
if [[ "$status" != *"HTTP/1.1 201"* ]] && [[ "$status" != *"HTTP/1.1 202"* ]]; then
    exit 1
fi

# We got and artifact that we can extract
if [[ "$status" = *"HTTP/1.1 202"* ]]; then
    ARTIFACT_MD5=`printf '%s' "ZKBUILD_$BITBUCKET_SERVER_URL/$BITBUCKET_COMMIT" | md5sum | awk '{print $1}'`
    ARTIFACT="$ARTIFACT_MD5.zip"
    wget -q https://operations.zeugwerk.dev/public/$ARTIFACT
    if [[ $? -ne 0 ]]; then
        exit 202
    fi
    
    # return code 0 means no errors
    # return code 1 means there was an error or warning, but processing was successful anyway
    unzip -q -o $ARTIFACT
    if [[ $? -gt 1 ]]; then
        exit 202
    fi
fi
