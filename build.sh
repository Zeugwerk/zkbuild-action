#!/usr/bin/env bash

BRANCH=$GITHUB_HEAD_REF
if [ "$BRANCH" == "" ]; then
    BRANCH=$(echo $GITHUB_REF | sed 's/refs\/heads\///');
fi;
BRANCH=$(echo -n $BRANCH | tr "/" "-")

curl -s -N -G --data-urlencode "scm=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY" --data-urlencode "sha=$GITHUB_SHA" --data-urlencode "branch=$BRANCH" --data-urlencode "username=$1" --data-urlencode "password=$2" --data-urlencode "tcversion=$3" --data-urlencode "working-directory=$4" --data-urlencode "method=zkbuild" https://zeugwerk.at/api.php | tee response
status="$(tail -n1 response)"
if [[ "$status" != *"HTTP/1.1 200"* ]]; then
    exit 1
fi

ARTIFACT_MD5=`printf '%s' "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY" | md5sum | awk '{print $1}'`
ARTIFACT="$1_zkbuild_$ARTIFACT_MD5.zip"
wget https://zeugwerk.at/public/$ARTIFACT
if [[ $? -ne 0 ]]; then
    exit 1
fi

unzip -o $ARTIFACT
if [[ $? -ne 0 ]]; then
    exit 1
fi
