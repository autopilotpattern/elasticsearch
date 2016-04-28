#!/bin/bash

MASTER=null

if [[ -z ${CONSUL} ]]; then
    echo "Missing CONSUL environment variable"
    exit 1
fi

preStart() {
    # happy path is that there's a master available and we can cluster
    configureMaster

    # data-only nodes can only loop until there's a master available
    if [ ${ES_NODE_MASTER} == false ]; then
        while true
        do
            sleep 1.7
            configureMaster
        done
        exit 0
    fi

    # for a master+data node, we'll retry to see if there's another
    # master in the cluster in the process of starting up. But we
    # bail out if we exceed the retries and just bootstrap the cluster
    if [ ${ES_NODE_DATA} == true ]; then
        local n=0
        until [ $n -ge 2 ]
        do
            sleep 1.7
            configureMaster
            n=$((n+1))
        done
    fi

    # for a master-only node or master+data node that's exceeded the
    # retry attempts, we'll assume this is the first master and bootstrap
    # the cluster
    MASTER=127.0.0.1
    replace
}

# get the list of ES master nodes from Consul
configureMaster() {
    MASTER=$(curl -Ls --fail http://${CONSUL}:8500/v1/catalog/service/elasticsearch-master | jq -r '.[0].ServiceAddress')
    if [[ $MASTER != "null" ]] && [[ -n $MASTER ]]; then
        replace
        exit 0
    fi
    # if there's no master we fall thru and let the caller figure
    # out what to do next
}

# update discovery.zen.ping.unicast.hosts
replace() {
    REPLACEMENT=$(printf 's/^discovery\.zen\.ping\.unicast\.hosts.*$/discovery.zen.ping.unicast.hosts: ["%s"]/' ${MASTER})
    sed -i "${REPLACEMENT}" /etc/elasticsearch/elasticsearch.yml
}

health() {
    local privateIp=$(ip addr show eth0 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    /usr/bin/curl --fail -s -o /dev/null http://${privateIp}:9200
}

# do whatever the arg is
$1
