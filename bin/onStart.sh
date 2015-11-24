#!/bin/bash

MASTER=
while true
do
    # get the list of master-only nodes from Consul
    MASTER=$(curl -Ls http://consul:8500/v1/catalog/service/elasticsearch-master | jq -r '.[0].ServiceAddress')
    if [[ $MASTER != "null" ]] && [[ -n $MASTER ]]; then
        break
    fi
    # if this is the first master-only node, use itself to bootstrap
    if [ ${ES_NODE_MASTER} == true ] && [ ${ES_NODE_DATA} == false ]; then
        MASTER=127.0.0.1
        break
    fi
    # this is not a master-only node and there are not master-only
    # nodes up yet, so wait and retry
    sleep 1.7
done

# update discovery.zen.ping.unicast.hosts
REPLACEMENT=$(printf 's/${ES_BOOTSTRAP_HOST}/%s/' ${MASTER})
sed -i ${REPLACEMENT} /etc/elasticsearch/default.yml
