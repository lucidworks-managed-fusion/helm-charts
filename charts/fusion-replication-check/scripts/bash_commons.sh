#!/usr/bin/env bash

export SCRIPT_NAME=$(basename $0)
if [ -z $BASE_DIR ] ; then
    export BASE_DIR=$(cd `dirname $0` ; pwd)
fi
export CURR_DIR=$(pwd)

export COMMONS_DIR=$(cd `dirname ${BASH_SOURCE[0]}` ; pwd)

if [ -z $WORK_DIR ] ; then
    export WORK_DIR="$COMMONS_DIR/results"
fi

# if [ ! -d $WORK_DIR ] ; then
#   mkdir -p $WORK_DIR
# fi

function wipeout_double_quotes() {
    sed 's/^"//;s/"$//'
}

function get_json_property {
    typeset var local PROP_NAME=$1
    jq ".${PROP_NAME}" | wipeout_double_quotes
}

function urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%%%02X' "'$c" ;;
    esac
    done
    
    LC_COLLATE=$old_lc_collate
}


function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }


function url_encode_file(){
    typeset var local FILE="${1}"
    typeset var local OLD_IFS=$IFS
    typeset var local LINE=
    IFS=$'\n'
    sed 's/[^[:print:]]//g' $FILE | while read LINE  ; do
    urlencode $LINE
    echo
    done
    IFS=$OLD_IFS
}


function to_pascal_case() {
    typeset var local TEXT="$1"
    for WORD in $(echo ${TEXT[@]^} | tr '[A-Z]' '[a-z]') ; do
    FirstLeter=$(echo $WORD | cut -c1 | tr '[a-z]' '[A-Z]')
    Rest=$(echo $WORD | cut -c2 )
    printf "%s%s" $FirstLeter ${WORD:1}
    done
    printf "\n"
}

function test_command {
    typeset var local COMMAND=$1
    typeset var local exitSts=0
    which $COMMAND >/dev/null 2>&1
    exitSts=$?
    if [ $exitSts -eq 0 ] ; then
    echo 0
    else
    echo 1
    fi
}

function command_exists {
    typeset var local COMMAND="$1"
    [ $(test_command "$COMMAND") -eq 0 ]
}

function generate_random_password() {
    typeset var local LENGTH=16
    if [ $# -gt 0 ] ; then
    LENGTH=$1
    fi
    typeset var local RESULT=
    while [ -z $RESULT ] ; do
    RESULT=$(date +%s | sha256sum | base64 | head -c $LENGTH ; echo | awk '/[a-z]/ && /[A-Z]/ && /[0-9]/' ; echo)
    if  [[ ! $RESULT =~ [0-9] ]] || [[ ! $RESULT =~ [a-z] ]] || [[ ! $RESULT =~ [A-Z] ]] ; then
        RESULT=
    fi
    done
    echo $RESULT
}

function test_command {
    typeset var local COMMAND=$1
    typeset var local exitSts=0
    which $COMMAND >/dev/null 2>&1
    exitSts=$?
    if [ $exitSts -eq 0 ] ; then
    echo 0
    else
    echo 1
    fi
}

function command_exists {
    typeset var local COMMAND="$1"
    [ $(test_command "$COMMAND") -eq 0 ]
}

function generate_random_password() {
    typeset var local LENGTH=16
    if [ $# -gt 0 ] ; then
    LENGTH=$1
    fi
    typeset var local RESULT=
    while [ -z $RESULT ] ; do
    RESULT=$(date +%s | sha256sum | base64 | head -c $LENGTH ; echo | awk '/[a-z]/ && /[A-Z]/ && /[0-9]/' ; echo)
    if  [[ ! $RESULT =~ [0-9] ]] || [[ ! $RESULT =~ [a-z] ]] || [[ ! $RESULT =~ [A-Z] ]] ; then
        RESULT=
    fi
    done
    echo $RESULT
}

function get_OS_name() {
    OS_NAME=$(uname -s)
    if [ "$OS_NAME" == "Darwin" ] ; then
    echo "macos"
    elif [ "$OS_NAME" == "Linux" ] ; then
    echo "linux"
    else
    echo "unknown"
    fi
}

OS_NAME=$(get_OS_name)
if [ "$OS_NAME" == "macos" ] ; then
    export DATE_CMD=gdate
else
    export DATE_CMD=date
fi
# $TODO: change gdate to date
# DATE_CMD=gdate

function date2stamp() {
    $DATE_CMD --utc --date "$1" +%s
}

function dateDiff() {
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp "$1")
    dte2=$(date2stamp "$2")
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec))
}