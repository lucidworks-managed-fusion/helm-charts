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

export LIVE_NODES=$(mktemp)

get_solr_nodes | sort | uniq > $LIVE_NODES

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
    # echo $COLLECTION
    get_collection_details $COLLECTION  | jq -r '.[] | [.collection, .shard, .type, .state, .replica, .core, .node_name, .base_url, .leader] | @tsv' >> $COLLECTIONS_INFO
done < <(cat $COLLECTIONS ; echo)

export DETAILS=$(mktemp)
export REPLICATION_DETAILS=$(mktemp)
touch $REPLICATION_DETAILS

export PROBLEMS=$(mktemp)
touch $PROBLEMS

while read COLLECTION SHARD TYPE STATE REPLICA CORE NODE_NAME BASE_URL LEADER ; do
    if [ "$STATE" == "active" ] ; then
        #TODO: Uncomment this line to use the local solr   
        # get_replication_details $COLLECTION "http://localhost:8983/solr" >$DETAILS
        # get_replication_details $COLLECTION "${BASE_URL}" > $DETAILS
        SOLR_NAME=$(echo $NODE_NAME | awk -F '.' '{print $1}')
        get_replication_status "${CORE}" "${COLLECTION}" "${SHARD}" "${LEADER}" > $DETAILS
        status=$?
        if [ $status -eq 0 ] ; then
            # jq -r '[.collection, .core, .shard, .replica, .index_version, .generation] | @tsv' $DETAILS | sed "s/generation=.*,version=/$LEADER\t/g" >> $REPLICATION_DETAILS
            jq -r '[.collection, .replica, .shard, .indexVersion, .generation] | @tsv' $DETAILS | sed "s|$|\t${SOLR_NAME}\t${LEADER}|g" >> $REPLICATION_DETAILS
        else
            #echo "Error - $BASE_URL connection timeout" >&2
            add_timeout_error $BASE_URL
        fi
    fi
done < $COLLECTIONS_INFO

export LEADERS=$(mktemp)
export FOLLOWERS=$(mktemp)
grep 'true$' $REPLICATION_DETAILS > $LEADERS
grep 'false$' $REPLICATION_DETAILS > $FOLLOWERS
# Use to simulate errors
#head -n 3 $FOLLOWERS | sed 's|[0-9]*\(\t[[:graph:]]*\tfalse\)$|3214\1|g'  >> $FOLLOWERS
export ERRORS=$(mktemp)


while read COLLECTION ; do
    if [[ "$COLLECTION" == \#* ]] | [[ "$COLLECTION" == '^\s*$' ]] ; then
        continue
    fi
    while read COL_NAME CORE SHARD INDEX_VERSION GENERATION NODE_NAME LEADER ; do
        EQUALS=$(grep "^$COLLECTION\t[^ ]*\t${SHARD}\t${INDEX_VERSION}\t${GENERATION}\t" $FOLLOWERS | wc -l)
        TOTAL=$(grep "^$COLLECTION\t[^ ]*\t${SHARD}" $FOLLOWERS | wc -l)
        if [ $EQUALS -ne $TOTAL ] ; then
            echo "Problem - $COLLECTION $SHARD $CORE $INDEX_VERSION $GENERATION" >> $PROBLEMS
            while read ECOL_NAME ECORE ESHARD EINDEX_VERSION EGENERATION NODE_NAME ELEADER ; do
                if [ $EGENERATION -eq $GENERATION ] ; then
                    continue
                fi
                add_replication_error $COLLECTION $SHARD $ECORE $EINDEX_VERSION $EGENERATION $INDEX_VERSION $GENERATION $NODE_NAME
            done < <(grep "^$COLLECTION\t[^ ]*\t${SHARD}" $FOLLOWERS | grep -v "\t${INDEX_VERSION}\t${GENERATION}$")            
        fi
    done < <(grep "^$COLLECTION\t[^ ]*\t" $LEADERS)
done < <(cat $COLLECTIONS ; echo)


echo '{ "errors": { "timeout": ' > $ERRORS

cat $TIMEOUT_ERRORS | jq -s '.' >>$ERRORS 
echo ', "replication": ' >> $ERRORS
cat $REPLICATION_ERRORS | jq -s '.' >>$ERRORS
echo '}}' >> $ERRORS
cat $ERRORS | jq '.'

rm -f $LIVE_NODES $COLLECTIONS_INFO $LEADERS $FOLLOWERS $DETAILS $REPLICATION_DETAILS $PROBLEMS $TIMEOUT_ERRORS $REPLICATION_ERRORS $ERRORS