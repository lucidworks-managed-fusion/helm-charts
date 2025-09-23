#!/usr/bin/env bash

if [ -z $COMMONS_DIR ] ; then
    export COMMONS_DIR=$(cd `dirname ${BASH_SOURCE[0]}` ; pwd)
fi

. $COMMONS_DIR/bash_commons.sh

function get_time_stamp() {
    date +%Y%m%d%H%M%S
}

function get_script_stamp() {
    if [ -z $_TIMESTAMP ] ; then
    export _TIMESTAMP=$(get_time_stamp)
    fi
    echo $_TIMESTAMP
}

function get_time_increaser() {
    if [ -z $_INCREASER ] ; then
    export _INCREASER=0
    fi
    ((_INCREASER+=1))

    echo $(get_script_stamp)"${_INCREASER}"
}

function call_solr_api() {
    typeset var local CMD="$1"
    if [ $# -eq 2 ] ; then
    typeset var local SOLR_URL="$2"
    fi
    curl -s -XGET "$SOLR_URL/${CMD}"
}

function get_solr_svc() {
    kubectl get svc -l app.kubernetes.io/name=solr,service-type=headless --no-headers | awk '{print $1}' | sort -r | head -n 1
}

function get_solr_nodes() {
    call_solr_api "admin/collections?action=CLUSTERSTATUS" | jq '.cluster.live_nodes[]' | tr -d '"' | sort | uniq
}

function get_collections() {
    call_solr_api "admin/collections?action=LIST" | jq '.collections[]' | tr -d '"' | sort | uniq
}

function get_collection_details() {
    typeset var local COL_NAME="$1"
    call_solr_api "admin/collections?action=CLUSTERSTATUS" | jq "
    .cluster.collections | to_entries | .[] | select(.key == \"${COL_NAME}\") as \$parent | 
    \$parent.value.shards | to_entries | .[] as \$shards | 
    \$shards.value.replicas | to_entries | .[] as \$replicas |
    (if \$replicas.value.leader != null then \"true\" else \"false\" end) as \$isLeader | 
    { 
    collection: \$parent.key, 
    shard: \$shards.key, 
    type: \$replicas.value.type, 
    state: \$replicas.value.state, 
    replica: \$replicas.key, 
    core: \$replicas.value.core, 
    node_name: \$replicas.value.node_name, 
    base_url: \$replicas.value.base_url, leader: \$isLeader
    }
" | jq -s "."
}

function get_replication_details(){
    typeset var local COL_NAME="$1"
    typeset var local SOLR_URL="$2"
    typeset var local exitSts=0
    typeset var local OUTPUT=$(mktemp)
    curl -s --connect-timeout 60 -XGET "${SOLR_URL}/admin/metrics?expr=solr\.core\..*:REPLICATION\..*replication\.(generation|indexVersion|isFollower|isLeader).*&expr=solr\.core\..*:REPLICATION\..*replication\.fetcher.*" > $OUTPUT
    exitSts=$?
    cat $OUTPUT | jq "
.metrics | to_entries | .[] | select(.key | startswith(\"solr.core.\")) as \$parent |
\$parent.key | split(\".\") as \$parent_key_items |
\$parent_key_items | length as \$parent_key_item_len |
(if \$parent_key_item_len == 3 then \$parent_key_items[2] else \"\" end) as \$core |
(if \$parent_key_item_len == 5 then \$parent_key_items[2] else \"\" end) as \$collection |
(if \$parent_key_item_len == 5 then \$parent_key_items[3] else \"\" end) as \$shard |
(if \$parent_key_item_len == 5 then \$parent_key_items[4] else \"\" end) as \$replica |
(if \$parent_key_item_len == 5 then (\$collection + \"_\" + \$shard + \"_\" + \$replica) else \$core end) as \$core |
if \$parent_key_item_len == 3 then
\$parent.value | to_entries | .[] | select(.key == \"REPLICATION./replication.isLeader\") as \$object |
\$object.key | split(\".\")[0] as \$category |
\$object.key | split(\".\")[1] as \$handler |
{
    category: \$category,
    handler: \$handler,
    core: \$core,
}
else
\$parent.value | .\"REPLICATION./replication.generation\" as \$generation | 
\$parent.value | .\"REPLICATION./replication.fetcher\" | .indexReplicatedAt as \$replicated_at |
\$parent.value | .\"REPLICATION./replication.fetcher\" | .timesIndexReplicated as \$times_replicated |
\$parent.value | .\"REPLICATION./replication.indexVersion\" as \$index_version |
{
    core: \$core,
    collection: \$collection,
    shard: \$shard,
    replica: \$replica,
    replicated_at: \$replicated_at,
    times_replicated: \$times_replicated,
    index_version: \$index_version,
    generation: \$generation
} 
end
    " | jq -s ".[] | select (.collection == \"${COL_NAME}\")"
rm -f $OUTPUT
return $exitSts
}

function get_replication_status() {
    typeset var local CORE="$1"
    typeset var local COLLECTION="$2"
    typeset var local SHARD="$3"
    typeset var local LEADER="$4"
    call_solr_api "${CORE}/replication?command=details" | jq "
.details as \$details | .status as \$status | \$details.follower as \$follower | \$follower.leaderDetails as \$leaderDetails
| (if \$follower.timesFailed != null then \$follower.timesFailed else 0 end) as \$timesFailed
| (if \$follower.replicationFailedAt != null then \$follower.replicationFailedAt else \"null\" end) as \$replicationFailedAt
| {
    \"collection\": \"${COLLECTION}\",
    \"shard\": \"${SHARD}\",
    \"replica\": \"${CORE}\",
    \"isLeader\": \"${LEADER}\",
    \"indexVersion\": \$details.indexVersion, 
    \"generation\": \$details.generation,
    \"isReplicating\": \$follower.isReplicating,
    \"leaderIndexVersion\": \$leaderDetails.indexVersion,
    \"leaderGeneration\": \$leaderDetails.generation,
    \"replicableVersion\": \$leaderDetails.leader.replicableVersion,
    \"replicableGeneration\": \$leaderDetails.leader.replicableGeneration,
    \"isReplicating\": \$follower.isReplicating,
    \"replicationFailedAt\": \$replicationFailedAt,
    \"currentDate\": \$follower.currentDate,
    \"timesFailed\": \$timesFailed,
    \"leaderUrl\": \$follower.leaderUrl,
    \"indexReplicatedAt\": \$follower.indexReplicatedAt
}
" | jq -s ".[]" 
}

function get_index_version() {
  typeset var local CORE="$1"
  call_solr_api "${CORE}/replication?command=indexversion" | jq "
  {
     \"indexVersion\": .indexversion, 
     \"generation\": .generation,
     \"status\": .status,
  }
  " | jq "."

}

function get_leaders() {
    typeset var local COL_NAME="$1"
    get_collection_details $COL_NAME | jq ".[] | select(.leader == \"true\")" | jq -s "."
}

function get_followers(){
    typeset var local COL_NAME="$1"
    get_collection_details $COL_NAME | jq ".[] | select(.leader == \"false\")" | jq -s "."
}

function get_collection_info() {
    typeset var local COL_NAME="$1"
    call_solr_api "admin/collections?action=CLUSTERSTATUS" | jq ".cluster.collections.\"${COL_NAME}\"" 
}

function get_collection_status() {
    typeset var local COL_NAME="$1"
    call_solr_api "admin/collections?action=COLSTATUS&collection=${COL_NAME}&coreInfo=false&segments=false&fieldInfo=false&sizeInfo=false"

}

function get_collection_shards() {
    typeset var local COL_NAME="$1"
    get_collection_info $COL_NAME | jq -r '.shards | keys | .[]'
}

function get_collection_shard_replicas() {
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    get_collection_info "$COL_NAME" | jq -r ".shards.${SHARD}.replicas | keys | .[]" | sort | uniq 
}

function get_collection_shard_replica_status() {
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    typeset var local REPLICA="$3"
    get_collection_info "$COL_NAME" | jq ".shards.${SHARD}.replicas.${REPLICA}"
}

function get_collection_shard_replica_leader(){
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    typeset var local REPLICA=
    typeset var local LEADER=
    typeset var local is_leader=
    for REPLICA in $(get_collection_shard_replicas $COL_NAME $SHARD) ; do
    is_leader=$(get_collection_shard_replica_status $COL_NAME $SHARD $REPLICA | jq -r ".leader")
    if [[ $is_leader == "true" ]] ; then 
        LEADER=$REPLICA
        break;
    fi
    done
    if [ ! -z $LEADER ] ; then
    echo $LEADER
    fi
}

function move_replica() {
    typeset var local COLLECTION="$1"
    typeset var local SHARD="$2"
    typeset var local REPLICA="$3"
    typeset var local SOURCE_NODE="$4"
    typeset var local TARGET_NODE="$5"
    typeset var local async_time=$(get_time_increaser)
    #echo "admin/collections?action=MOVEREPLICA&collection=${COLLECTION}&shard=${SHARD}&replica=${REPLICA}&sourceNode=${SOURCE_NODE}&targetNode=${TARGET_NODE}"
    call_solr_api "admin/collections?action=MOVEREPLICA&collection=${COLLECTION}&shard=${SHARD}&replica=${REPLICA}&sourceNode=${SOURCE_NODE}&targetNode=${TARGET_NODE}&async=${async_time}"
}

function add_replica() {
    typeset var local COLLECTION="$1"
    typeset var local SHARD="$2"
    typeset var local TARGET_NODE="$3"
    typeset var local TYPE="$4"
    typeset var local async_time=$(get_time_increaser)
    typeset var local CMD="admin/collections?action=ADDREPLICA&collection=${COLLECTION}&shard=${SHARD}&node=${TARGET_NODE}&type=${TYPE}&async=${async_time}"
    call_solr_api "$CMD"
}

function delete_replica() {
    typeset var local COLLECTION="$1"
    typeset var local SHARD="$2"
    typeset var local REP_NAME="$3"
    typeset var local async_time=$(get_time_increaser)
    typeset var local CMD="admin/collections?action=DELETEREPLICA&collection=${COLLECTION}&shard=${SHARD}&replica=${REP_NAME}&async=${async_time}"
    if [ ! -z $DELETE_ENABLED ] && [[ "$DELETE_ENABLED" == "YES" ]] ; then
    call_solr_api "$CMD"
    else
    echo "Delete disabled, call to disable collection:[$COLLECTION] shard:[$SHARD] replica:[$REP_NAME] was not applied."
    if [ ! -z $DELETE_FILE ] ; then
        touch $DELETE_FILE
        echo "curl -s -XGET ${SOLR_URL}/${CMD}" >> $DELETE_FILE 
    fi
    fi
}

function get_replica_nodes_detail() {
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    get_collection_info "$COL_NAME" | jq ".shards.${SHARD}.replicas" | jq -r ' keys[] as $k | "\(.[$k] | .node_name) \(.[$k] | .type) \(.[$k] | .state) \(.[$k] | .leader) \($k)"'
}

function get_replica_nodes() {
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    get_replica_nodes_detail "$COL_NAME" "$SHARD" | awk '{print $1" "$2" "$5}'
}


function get_collection_shards_status() {
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    get_collection_info $COL_NAME | jq -r ".shards.${SHARD}.replicas[] | select(.leader) | \"\(.core) \(.type) \(.node_name) \(.state) \""
}

function get_replica_leader_detail() {
    typeset var local COL_NAME="$1"
    typeset var local SHARD="$2"
    get_replica_nodes_detail $COL_NAME $SHARD | grep -v "[^ ]* null [^ ]*$"
}

function xor_file_lines(){
    FILE1="$1"
    FILE2="$2"
    typeset var local RESULT_FILE=$(mktemp)
    cat $FILE1 > $RESULT_FILE
    while read LINE ; do
    sed -i '' "/^${LINE}$/d" $RESULT_FILE
    done < $FILE2
    car $RESULT_FILE
    rm -f $RESULT_FILE 
}

function get_collection_schema() {
    typeset var local COLLECTION="$1"
    typeset var local CMD="${COLLECTION}/admin/file?wt=json&file=managed-schema&contentType=text%2Fplain%3Bcharset%3Dutf-8"
    call_solr_api "${CMD}"
}


export SOLR_URL="http://localhost:8983/solr"
export SEARCH_TYPE="NRT"
export MAX_INDEX=5
export DELETE_ENABLED="NO"
export DELETE_FILE=""
