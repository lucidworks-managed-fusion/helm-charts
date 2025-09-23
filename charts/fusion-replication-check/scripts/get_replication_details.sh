#!/usr/bin/env bash

export COMMONS_DIR=$(cd `dirname ${BASH_SOURCE[0]}` ; pwd)

. $COMMONS_DIR/solr_collections_commons.sh
. $COMMONS_DIR/json_commons.sh

export SOLR_SVC=$(get_solr_svc)

#TODO: Comment this before commit
# export SOLR_SVC="localhost"

export SOLR_URL="http://$SOLR_SVC:8983/solr"

export COLLECTIONS=$1

export COLLECTIONS_INFO=$(mktemp)

touch $COLLECTIONS_INFO
while read COLLECTION ; do
    if [[ "$COLLECTION" == \#* ]] | [[ "$COLLECTION" == '^\s*$' ]] ; then
        continue
    fi
    COLLECTION_EXISTS=$(get_collections | grep "^${COLLECTION}$" | wc -l)
    if [ $COLLECTION_EXISTS -eq 0 ] ; then
        #echo "Error - Collection $COLLECTION does not exist" >&2
        continue
    fi
    get_collection_details $COLLECTION  | jq -r '.[] | [.collection, .shard, .type, .state, .replica, .core, .node_name, .base_url, .leader] | @tsv' >> $COLLECTIONS_INFO
done < <(cat $COLLECTIONS ; echo)

export DETAILS=$(mktemp)
export REPLICATION_DETAILS=$(mktemp)
touch $REPLICATION_DETAILS

export PROBLEMS=$(mktemp)
touch $PROBLEMS

while read COLLECTION SHARD TYPE STATE REPLICA CORE NODE_NAME BASE_URL LEADER ; do
    if [ "$STATE" == "active" ] ; then
        get_replication_status "${CORE}" "${COLLECTION}" "${SHARD}" "${LEADER}" > $DETAILS
        jq -r '[.collection, .shard, .isLeader, .replica, .indexVersion, .generation, .isReplicating, .leaderIndexVersion, .leaderGeneration, .replicableVersion, .replicableGeneration, .replicationFailedAt, .currentDate, .timesFailed, .leaderUrl, .indexReplicatedAt] | @csv' $DETAILS >> $REPLICATION_DETAILS
    fi
done < $COLLECTIONS_INFO


export LEADERS=$(mktemp)
export FOLLOWERS=$(mktemp)
grep '^[^,]*,[^,]*,\"true\"' $REPLICATION_DETAILS > $LEADERS
grep '^[^,]*,[^,]*,\"false\"' $REPLICATION_DETAILS > $FOLLOWERS
#grep '^[^ ]*\t[^ ]*\t[^ ]*\t[^ ]*\tfalse' $REPLICATION_DETAILS > $FOLLOWERS
# Use to simulate errors
#head -n 3 $FOLLOWERS | sed 's/[0-9]*$/3214/g' >> $FOLLOWERS

while IFS=, read -r COLLECTION SHARD IS_LEADER REPLICA INDEX_VERSION GENERATION IS_REPLICATING LEADER_INDEX_VERSION LEADER_GENERATION REPLICABLE_VERSION REPLICABLE_GENERATION REPLICATION_FAILED_AT CURRENT_DATE TIMES_FAILED LEADER_URL INDEX_REPLICATED_AT
do
    if [ $TIMES_FAILED -gt 0 ] ; then
        if [ $LEADER_GENERATION -ne $GENERATION ] ; then
            REPLICATION_FAILED_AT=$(echo $REPLICATION_FAILED_AT | sed 's/"//g')
            INDEX_REPLICATED_AT=$(echo $INDEX_REPLICATED_AT | sed 's/"//g')
            FAILED_HRS=$(dateDiff -h "$REPLICATION_FAILED_AT"  "$INDEX_REPLICATED_AT")
            # FAILED_HRS=$(dateDiff -h "$INDEX_REPLICATED_AT" "$REPLICATION_FAILED_AT")
            # echo $FAILED_HRS
            if [ $FAILED_HRS -lt -4 ] ; then
                get_replication_status $(echo "${REPLICA} ${COLLECTION} ${SHARD} ${IS_LEADER}" | sed 's/"//g') >> $REPLICATION_ERRORS
                # echo "$COLLECTION $SHARD $IS_LEADER $REPLICA $INDEX_VERSION $GENERATION $IS_REPLICATING $LEADER_INDEX_VERSION $LEADER_GENERATION $REPLICABLE_VERSION $REPLICABLE_GENERATION $REPLICATION_FAILED_AT $CURRENT_DATE $TIMES_FAILED $LEADER_URL $INDEX_REPLICATED_AT" >2
            fi
        fi
    fi
done < <(grep '^[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,\"false\"' $FOLLOWERS)

export ERRORS=$(mktemp)

echo '{ "errors": { "timeout": []' > $ERRORS

echo ', "replication": ' >> $ERRORS
cat $REPLICATION_ERRORS | jq -s '.' >>$ERRORS
echo '}}' >> $ERRORS
cat $ERRORS | jq '.'


rm -f $COLLECTIONS_INFO $EXSISTING_COLLECTIONS $DETAILS $REPLICATION_DETAILS $PROBLEMS $LEADERS $FOLLOWERS $REPLICATION_ERRORS $ERRORS

exit 0