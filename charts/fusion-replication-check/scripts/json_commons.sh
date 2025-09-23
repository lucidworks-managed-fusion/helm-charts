#!/usr/bin/env bash

export SCRIPT_NAME=$(basename $0)
if [ -z $BASE_DIR ] ; then
    export BASE_DIR=$(cd `dirname $0` ; pwd)
fi
export CURR_DIR=$(pwd)

export COMMONS_DIR=$(cd `dirname ${BASH_SOURCE[0]}` ; pwd)


export TIMEOUT_ERRORS=$(mktemp)
touch $TIMEOUT_ERRORS
#echo '[' > $TIMEOUT_ERRORS


function add_timeout_error() {
    typeset var local BASE_URL="$1"
    echo "{\"base_url\": \"$BASE_URL\"}" >> $TIMEOUT_ERRORS
}

export REPLICATION_ERRORS=$(mktemp)
touch $REPLICATION_ERRORS

function add_replication_error() {
    typeset var local COLLECTION="$1"
    typeset var local SHARD="$2"
    typeset var local REPLICA="$3"
    typeset var local INDEX_VERSION="$4"
    typeset var local GENERATION="$5"
    typeset var local LEADER_VERSION="$6"
    typeset var local LEADER_GENERATION="$7"
    typeset var local NODE_NAME="$8"
    echo "{\"collection\": \"$COLLECTION\", \"shard\": \"$SHARD\", \"replica\": \"$REPLICA\", \"version\": \"$INDEX_VERSION\", \"generation\":\"$GENERATION\", \"leader_version\": \"${LEADER_VERSION}\", \"leader_generation\": \"${LEADER_GENERATION}\", \"pod_name\": \"${NODE_NAME}\"}" >> $REPLICATION_ERRORS
}