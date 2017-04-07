#!/bin/bash

MASTER=null
CONSUL_HOST=${CONSUL}
CONSUL_AGENT=${CONSUL_AGENT:=false}

readonly lockPath=service/elasticsearch-master/locks/master

if [ $CONSUL_AGENT != false ]; then
    CONSUL_HOST='localhost'
fi

if [[ -z $CONSUL_HOST ]]; then
    echo "Missing CONSUL environment variable"
    exit 1
fi

consulCommand() {
    consul-cli --quiet --consul="${CONSUL_HOST}:8500" $*
}

onStart() {
    logDebug "onStart"

    waitForLeader

    getRegisteredServiceName
    if [[ "${registeredServiceName}" == "elasticsearch-data" ]]; then

        # wait for a healthy master
        local i
        for (( i = 0; i < ${MASTER_WAIT_TIMEOUT-60}; i++ )); do
            getServiceAddresses "elasticsearch-master"
            if [[ ${serviceAddresses} ]]; then
                MASTER=$serviceAddresses
                break
            fi
            sleep 1
        done

    else

        # wait for a healthy master
        local i
        for (( i = 0; i < ${MASTER_WAIT_TIMEOUT-60}; i++ )); do
            getServiceAddresses "elasticsearch-master"
            if [[ ${serviceAddresses} ]]; then
                MASTER=$serviceAddresses
                break
            fi
            sleep 1
        done

    fi

    # replace zen hosts
    replaceZenHosts
}

health() {
    local privateIp=$(ip addr show eth0 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    /usr/bin/curl --fail -s -o /dev/null http://${privateIp}:9200
}

waitForLeader() {
    logDebug "Waiting for consul leader"
    local tries=0
    while true
    do
        logDebug "Waiting for consul leader"
        tries=$((tries + 1))
        local leader=$(consulCommand --template="{{.}}" status leader)
        if [[ -n "$leader" ]]; then
            break
        elif [[ $tries -eq 60 ]]; then
            echo "No consul leader"
            exit 1
        fi
        sleep 1
    done
}

getServiceAddresses() {
    local serviceInfo=$(consulCommand health service --passing "$1")
    serviceAddresses=($(echo $serviceInfo | jq -r '.[].Service.Address'))
    logDebug "serviceAddresses $1 ${serviceAddresses[*]}"
}

getRegisteredServiceName() {
    registeredServiceName=$(jq -r '.services[0].name' /etc/containerpilot.json)
}

getNodeAddress() {
    nodeAddress=$(ifconfig eth0 | awk '/inet addr/ {gsub("addr:", "", $2); print $2}')
}

replaceZenHosts() {
    REPLACEMENT=$(printf 's/^discovery\.zen\.ping\.unicast\.hosts.*$/discovery.zen.ping.unicast.hosts: ["%s"]/' ${MASTER})
    sed -i "${REPLACEMENT}" /usr/share/elasticsearch/config/elasticsearch.yml
}

logDebug() {
    if [[ "${LOG_LEVEL}" == "DEBUG" ]]; then
        echo "manage: $*"
    fi
}

help() {
    echo "Usage: ./manage.sh preStart       => configure Consul agent"
    echo "       ./manage.sh onStart        => first-run configuration"
    echo "       ./manage.sh health         => health check Elastic"
    echo "       ./manage.sh preStop        => prepare for stop"
}

until
    cmd=$1
    if [[ -z "$cmd" ]]; then
        help
    fi
    shift 1
    $cmd "$@"
    [ "$?" -ne 127 ]
do
    help
    exit
done
