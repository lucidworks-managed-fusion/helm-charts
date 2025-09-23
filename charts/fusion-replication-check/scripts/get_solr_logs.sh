#!/usr/bin/env bash

export SCRIPT_NAME=$(basename $0)
if [ -z $BASE_DIR ] ; then
  export BASE_DIR=$(cd `dirname $0` ; pwd)
fi
export CURR_DIR=$(pwd)
export SCRIPTS_DIR=$(cd `dirname ${BASH_SOURCE[0]}` ; pwd)

. $SCRIPTS_DIR/bash_commons.sh

QUERY_PIPELINE="app.kubernetes.io/component=query-pipeline"
SOLR="app.kubernetes.io/name=solr,app.kubernetes.io/component=server"
SOLR="app.kubernetes.io/name=solr"


INTERVAL=5
SELECTOR=$SOLR
TIMESTAMP=$(TZ=UTC date +%Y%m%d_%H%M%S)
# NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')

function prep_term() {
  unset term_child_pid
  unset term_kill_needed
  trap 'handle_term' SIGINT SIGTERM ERR EXIT
}

function usage() {
  echo "
  Usage:
  ${SCRIPT_NAME} -h shows this help
  -s [SELECTOR]  : Selector for the pods
  -n [NAMESPACE] : Namespace for the pods
  "
  exit 0
}

function copy_files() {
  typeset var local POD_NAME=$1
  typeset var local FOLDER_NAME=$2

  kubectl cp $NAMESPACE/$POD_NAME:/opt/solr/server/solr/configsets/_default/conf/solrconfig.xml $FOLDER_NAME/solrconfig.xml >/dev/null 2>&1
  if [ ! -z $DUMP_HEAD ] ; then
    kubectl exec -it $POD_NAME -c solrcloud-node -n $NAMESPACE -- /bin/sh -c '/usr/bin/jattach $(ps aux | grep "[j]ava" | awk "{print \$2}") dumpheap /var/solr/logs/solr.heap ' >/dev/null 2>&1
    kubectl cp $NAMESPACE/$POD_NAME:/var/solr/logs/solr.heap $FOLDER_NAME/logs/solr.heap --retries=3 >/dev/null 2>&1
    kubectl exec -it $POD_NAME -c solrcloud-node -n $NAMESPACE -- /bin/sh -c 'rm -f /var/solr/logs/solr.heap ' >/dev/null 2>&1
  fi
  if [ ! -z $THREAD_DUMP ] ; then
    kubectl exec -it $POD_NAME -c solrcloud-node -n $NAMESPACE -- /bin/sh -c '/usr/bin/jattach $(ps aux | grep "[j]ava" | awk "{print \$2}") threaddump' > "$FOLDER_NAME/logs/solr.threaddump"  2>/dev/null
  fi

  FILENAMES=$(kubectl exec -it $POD_NAME -c solrcloud-node -n $NAMESPACE -- /bin/sh -c 'cd /var/solr/logs ; ls  solr.log* *slow_request* ' 2>/dev/null)
  for FILENAME in ${FILENAMES[@]} ; do
    FILENAME=$(echo $FILENAME | sed 's/\r$//' )
    kubectl cp -c solrcloud-node $NAMESPACE/$POD_NAME:/var/solr/logs/$FILENAME $FOLDER_NAME/logs/$FILENAME --retries=3 >/dev/null 2>&1
  done
  if [ ! -z $GC_LOGS ] ; then
    FILENAMES=$(kubectl exec -it $POD_NAME -c solrcloud-node -n $NAMESPACE -- /bin/sh -c 'cd /var/solr/logs ; ls  solr_gc.log* ' 2>/dev/null)
    for FILENAME in ${FILENAMES[@]} ; do
      FILENAME=$(echo $FILENAME | sed 's/\r$//' )
      kubectl cp -c solrcloud-node $NAMESPACE/$POD_NAME:/var/solr/logs/$FILENAME $FOLDER_NAME/logs/$FILENAME --retries=3 >/dev/null 2>&1
    done
  
  fi

}


function handle_term() {
  term_kill_needed="yes"
  kill -9 ${ALL_PIDS[@]}
#  for child_pid in ${ALL_PIDS[@]} ; do
#    kill -TERM "${child_pid}" 2>/dev/null 
#  done
}

function wait_term() {
  term_child_pid=$!
  if [ "${term_kill_needed}" ]; then
    kill -TERM "${term_child_pid}" 2>/dev/null 
  fi
  wait ${term_child_pid} 2>/dev/null
  trap - TERM INT
  wait ${term_child_pid} 2>/dev/null
}

function solr_pods_list(){
  for POD_NAME in ${SOLR_PODS[@]} ; do
    echo $POD_NAME
  done
}

INDEX=0
ALL_PIDS=()
DUMP_HEAD=
THREAD_DUMP=
REQUEST_LOGS=
GC_LOGS=

# SOLR_PODS=(internal-analytics-solrcloud-0 internal-standard-solrcloud-0)
SOLR_INDEX=0
FILTER=
while getopts "htdi:f:n:w:" opt; do
  case ${opt} in
    h ) usage
    ;;
    d ) DUMP_HEAD="yes"
    ;;
    t ) THREAD_DUMP="yes"
    ;;
    g ) GC_LOGS="yes"
    ;;
    r)  REQUEST_LOGS="yes"
    ;;
    i ) SOLR_PODS[SOLR_INDEX]=${OPTARG}
      ((SOLR_INDEX+=1))
    ;;
    f ) FILTER=${OPTARG}
    ;;
    n ) NAMESPACE=${OPTARG}
    ;;
    w ) WORK_DIR=$(cd ${OPTARG} ; pwd)
        if [ ! -d $WORK_DIR ] ; then
          echo "ERROR: The directory $WORK_DIR does not exist"
          exit -1
        fi
        cd $WORK_DIR
        if [ $? -ne 0 ] ; then
          echo "ERROR: Cannot change to the directory $WORK_DIR"
          exit -1
        fi
    ;;
    \? ) usage
    ;;
  esac
done

shift $((OPTIND -1))

if [ $SOLR_INDEX -eq 0 ] ; then
  SOLR_PODS=($(kubectl -n $NAMESPACE get pods -l "$SELECTOR" --no-headers | awk '{print $1}'))
fi

if [ ! -z "${FILTER}" ] ; then
  SOLR_PODS=($(solr_pods_list | grep $FILTER))
fi

for POD_NAME in ${SOLR_PODS[@]} ; do
  if [ "${term_kill_needed}" ] ; then
    continue
  fi
  FOLDER_NAME=${WORK_DIR}/solr_logs/$POD_NAME
  mkdir -pm 755 $FOLDER_NAME/logs

  copy_files $POD_NAME $FOLDER_NAME &

  ALL_PIDS[$INDEX]=$!
  trap - SIGTERM SIGINT
  ((INDEX+=1))
  if [ $INDEX -ge $INTERVAL ] ; then
    wait
    INDEX=0
    ALL_PIDS=()
  fi
done

wait

exit 0
