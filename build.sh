#!/usr/bin/env bash

# Get the current branch name
BRANCH=$GITHUB_HEAD_REF
if [ "$BRANCH" == "" ]; then
    BRANCH=$(echo $GITHUB_REF | sed 's/refs\/heads\///');
fi;
#BRANCH=$(echo -n $BRANCH | tr "/" "-")

# Run a build
curl -s --show-error -N -G --data-urlencode "scm=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY" --data-urlencode "sha=$GITHUB_SHA" --data-urlencode "branch=$BRANCH" --data-urlencode "username=$1" --data-urlencode "password=$2" --data-urlencode "tcversion=$3" --data-urlencode "working-directory=$4" --data-urlencode "method=zkbuild" https://operations.zeugwerk.dev/api.php | tee response
status="$(tail -n1 response)"

# Status is not SUCCESS and not UNSTABLE
if [[ "$status" != *"HTTP/1.1 201"* ]] && [[ "$status" != *"HTTP/1.1 202"* ]]; then
    exit 1
fi

# We got and artifact that we can extract
if [[ "$status" = *"HTTP/1.1 202"* ]]; then
    ARTIFACT_MD5=`printf '%s' "ZKBUILD_$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/$GITHUB_SHA" | md5sum | awk '{print $1}'`
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
