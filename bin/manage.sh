#!/bin/bash

MASTER=null
CONSUL_HOST=${CONSUL}
CONSUL_AGENT=${CONSUL_AGENT:=false}

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

    # replace zen hosts
    replaceZenHosts

    # disable seccomp (only supported on newer Linux kernels)
    replaceSeccomp
}

health() {
    local privateIp=$(ip addr show eth0 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    /usr/bin/curl --fail -s -o /dev/null http://${privateIp}:9200
}

waitForLeader() {
    logDebug "Waiting for consul server"
    local tries=0
    while true
    do
        logDebug "Waiting for consul server"
        tries=$((tries + 1))
        local server=$(consul members -status alive | grep server)
        if [[ -n "$server" ]]; then
            break
        elif [[ $tries -eq 60 ]]; then
            echo "No consul server"
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
    REPLACEMENT=$(printf 's/^# discovery\.zen\.ping\.unicast\.hosts.*$/discovery.zen.ping.unicast.hosts: ["%s"]/' ${MASTER})
    sed -i "${REPLACEMENT}" /usr/share/elasticsearch/config/elasticsearch.yml
}

replaceSeccomp() {
    SECCOMP_ENABLED=$(zcat /proc/config.gz | grep CONFIG_SECCOMP=y)
    if [[ "${SECCOMP_ENABLED}" != "CONFIG_SECCOMP=y" ]]; then
        echo "WARNING: seccomp unavailable, disabling system_call_filter..."
        REPLACEMENT=$(printf 's/^# bootstrap\.system_call_filter.*$/bootstrap.system_call_filter: false/')
        sed -i "${REPLACEMENT}" /usr/share/elasticsearch/config/elasticsearch.yml
    fi
}

logDebug() {
    if [[ "${LOG_LEVEL}" == "DEBUG" ]]; then
        echo "manage: $*"
    fi
}

help() {
    echo "Usage: ./manage.sh onStart        => first-run configuration"
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
