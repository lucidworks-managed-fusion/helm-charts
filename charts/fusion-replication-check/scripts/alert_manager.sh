#!/usr/bin/env bash

export COMMONS_DIR=$(cd `dirname ${BASH_SOURCE[0]}` ; pwd)

. $COMMONS_DIR/solr_collections_commons.sh

export COLLECTIONS=$1

function get_redis_svc() {
    kubectl get svc -l app=redis-stack-server --no-headers | awk '{print $1}' | sort -r | head -n 1
}

function create_pd_event(){
    if [ "$CREATE_PAGER_DUTY_EVENTS" != "true" ] ; then
        echo "PagerDuty events creation is disabled, skipping event creation" >&2
        return 0
    fi
    typeset var local ROUTING_KEY="$1"
    typeset var local EVENT_ACTION="trigger"
    typeset var local SEVERITY="critical"
    typeset var local CLASS="$2"
    typeset var local SUMMARY=
    typeset var local DEDUP_KEY=
    if [ $# -eq 3 ]; then
        DEDUP_KEY="$3"
    fi
    if [ $CLASS == "replication" ]; then
        SUMMARY="${CUSTOMER_NAME} Errors Encountered at index replication on $CLUSTER_NAME namespace ${NAMESPACE}"
    elif [ $CLASS == "timeout" ]; then
        SUMMARY="Errors timeout for some solr to acquire metrics on $CLUSTER_NAME"
    fi
    printf '{\n'
    printf '  "routing_key": "%s",\n' $ROUTING_KEY
    printf '  "event_action": "%s",\n' $EVENT_ACTION
    printf '  "payload": {\n'
    printf '    "severity": "%s",\n' $SEVERITY
    printf '    "source": "replication-alerter",\n'
    printf '    "summary": "%s",\n' "$SUMMARY"
    printf '    "component":  "solr",\n'
    printf '    "group": "replication",\n'
    printf '    "class": "%s",\n' $CLASS
    printf '    "custom_details": {\n'
    printf '    "details": "%s\\n' "$SUMMARY"
    printf '\\tcustomer: %s\\n'  "$CUSTOMER_NAME"
    printf '\\tcluster: %s\\n'  "$CLUSTER_NAME"
    printf '\\tcluster_type: %s\\n'  "$CLUSTER_TYPE"
    printf '\\tnamespace: %s\\n'  "$NAMESPACE"
    if [ $CLASS == "replication" ]; then
        printf '\\treplication_problems: [\\n'
        while read LINE_FON ; do 
            printf '%s' $LINE_FON
        done < <(echo "GET current" | $REDIS_CMD | jq -r '.errors.replication[]' | jq -R | sed 's/^"/\\\\t/g;s/"$/\\\\n/g;s/"/\\\\"/g'  )
        printf '\\t]\\n"'
    elif [ $CLASS == "timeout" ]; then
        printf '\\t\\ttimeout_problems: [\\n'
        while read BASE_URL ; do
            printf '\\t\\tbase_url: %s,\\n' $BASE_URL
        done < <(echo "GET current" | $REDIS_CMD | jq -r '.errors.timeout[] | [.base_url] | @tsv')
        printf '\\t]\\n"'
    fi
    printf '    }\n'
    printf '  }'
    if [ ! -z "$DEDUP_KEY" ]; then
        printf ',\n'
        printf '  "dedup_key": "%s"\n' $DEDUP_KEY
    else
        printf '\n'
    fi    
    printf '}\n'
}

#TODO: Uncomment this line to use the local solr
REDIS_HOST=$(get_redis_svc)
REDIS_PORT=$(kubectl get svc $REDIS_HOST -o jsonpath='{.spec.ports[0].port}')
# REDIS_HOST=localhost
# REDIS_PORT=6379

REDIS_CMD="redis-cli -h $REDIS_HOST -p $REDIS_PORT"

IS_NEW=$(echo "EXISTS current" | $REDIS_CMD | awk '{print $1}')
if [ $IS_NEW -eq 0 ]; then
    echo "{\n  \"errors\": {\n    \"timeout\": [],\n    \"replication\": []\n  }\n}" | $REDIS_CMD -x set current > /dev/null
fi

echo "COPY current last REPLACE" | $REDIS_CMD > /dev/null
#$COMMONS_DIR/get_replication_details.sh $COLLECTIONS | $REDIS_CMD -x set current >/dev/null
$COMMONS_DIR/check_replication.sh $COLLECTIONS | $REDIS_CMD -x set current >/dev/null

CURRENT=($(echo "GET current" | $REDIS_CMD | jq -r '.errors as $errors | $errors.timeout | length as $timeouts | $errors.replication | length as $replication | [$timeouts, $replication] | @tsv'))
LAST=($(echo "GET last" | $REDIS_CMD | jq -r '.errors as $errors | $errors.timeout | length as $timeouts | $errors.replication | length as $replication | [$timeouts, $replication] | @tsv'))
if [ ${CURRENT[1]} -ne 0 ] ; then
    echo "Replication errors found" >&2

    export SNAPSHOT_DIR="snapshot_`TZ=UTC date '+%Y-%m-%d_%H-%M-%S'`"
    rm -Rf $RESULTS_DIR/snapshot*

    if [ "$GET_LOGS" == "true" ] || [ "$GET_SNAPSHOT" == "true" ] ; then
        mkdir -p $RESULTS_DIR/$SNAPSHOT_DIR
        if [ "$GET_SNAPSHOT" == "true" ]; then
            echo "Taking environment snapshot..."
            echo "GET current" | $REDIS_CMD > ${RESULTS_DIR}/${SNAPSHOT_DIR}/replication_errors.json
            $COMMONS_DIR/snapshot.sh $NAMESPACE ${RESULTS_DIR}/$SNAPSHOT_DIR
        fi

        if [ "$GET_LOGS" == "true" ] ; then
            echo "Collecting solr logs..."
            $COMMONS_DIR/get_solr_logs.sh -n $NAMESPACE -w $RESULTS_DIR/$SNAPSHOT_DIR
        fi
        cd $RESULTS_DIR
        echo "Creating a snapshot zip file..."
        export FILE_NAME="${SNAPSHOT_DIR}.zip"

        zip -r -9 ${FILE_NAME} $SNAPSHOT_DIR
        rm -r $SNAPSHOT_DIR

        if [ ! -f ${GOOGLE_APPLICATION_CREDENTIALS} ] ; then
            echo ${GOOGLE_APPLICATION_CREDENTIALS}
            echo "No GOOGLE_APPLICATION_CREDENTIALS set, skipping upload to GCS"
        elif [ ! -z $GCS_BUCKET ] ; then
            echo "Uploading snapshot to GCS..."
            gsutil cp ${FILE_NAME} gs://$GCS_BUCKET/replication/snapshots/${NAMESPACE}/${FILE_NAME}
        fi
        rm -f ${FILE_NAME}
    fi
    if [ ${LAST[1]} -ne 0 ] ; then
        create_pd_event $REPLICATION_ROUTING_KEY "replication" |  jq '.' | curl -X POST -H "Content-Type: application/json" -d @- "https://events.pagerduty.com/v2/enqueue"
        echo "Alert replication errors" >&2
        echo "GET current" | $REDIS_CMD >&2
    else
        echo "Replication errors were found "
    fi
else
    echo "No replication errors"
fi

if [ ${CURRENT[0]} -ne 0 ] && [ ${LAST[0]} -ne 0 ] ; then
    create_pd_event $TIMEOUT_ROUTING_KEY "timeout" |  jq '.' | curl -X POST -H "Content-Type: application/json" -d @- "https://events.pagerduty.com/v2/enqueue"
    echo "Alert timeout errors" >&2
# else
#     echo "No timeout errors"
fi