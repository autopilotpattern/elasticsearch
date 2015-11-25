triton-elasticsearch
==========

[Elasticsearch](https://www.elastic.co/products) stack designed for container-native deployment on Joyent's Triton platform.

### Discovery with Containerbuddy

Cloud deployments can't take advantage of multicast over the software-defined networks available from AWS, GCE, or Joyent's Triton. Although a separate plugin could be developed to run discovery, in this case we're going to take advantage of a fairly typical production topology for Elasticsearch -- master-only nodes.

When a data node starts, it will use [Containerbuddy](https://github.com/joyent/containerbuddy) to query Consul and find a master node to bootstrap unicast zen discovery. We write this to the node configuration file on each start, so if the bootstrap node dies we can still safely reboot data nodes and join them to whatever master is available.

### Usage

1. [Get a Joyent account](https://my.joyent.com/landing/signup/) and [add your SSH key](https://docs.joyent.com/public-cloud/getting-started).
1. Install the [Docker Toolbox](https://docs.docker.com/installation/mac/) (including `docker` and `docker-compose`) on your laptop or other environment, as well as the [Joyent CloudAPI CLI tools](https://apidocs.joyent.com/cloudapi/#getting-started) (including the `smartdc` and `json` tools).

Launch a cluster with a single master-only node, a single data-only node, and a master/data node.

```bash
$ docker-compose -p es up -d
Pulling elasticsearch_master (0x74696d/triton-elasticsearch:latest)...
latest: Pulling from 0x74696d/triton-elasticsearch
...
Status: Downloaded newer image for 0x74696d/triton-elasticsearch:latest
Creating es_consul_1...
Creating es_elasticsearch_master_1...
Creating es_elasticsearch_1...
Creating es_data_1...
```

Scale up that cluster to 3 master/data nodes.

```bash
$ docker-compose -p es scale=elasticsearch=3
Creating and starting 2... done
Creating and starting 3... done

$ docker ps --format 'table {{ .ID }}\t{{ .Image }}\t{{ .Names }}'
CONTAINER ID        IMAGE                            NAMES
a0af06436c11        0x74696d/triton-elasticsearch    es_elasticsearch_data_1
d0df7ebe88d0        0x74696d/triton-elasticsearch    es_elasticsearch_master_1
1c8917b1064b        0x74696d/triton-elasticsearch    es_elasticsearch_1
e36436b26d05        0x74696d/triton-elasticsearch    es_elasticsearch_2
d9b96354c62f        0x74696d/triton-elasticsearch    es_elasticsearch_3
ad52bdd1a78e        progrium/consul:latest           es_consul_1

```

Let's check the cluster health.

```bash
$ MASTER_IP=$(docker inspect es_elasticsearch_master_1 | json -a NetworkSettings.IPAddress)
$ curl "http://${MASTER_IP}:9200/_cluster/health?pretty=true"
{
  "cluster_name" : "elasticsearch",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 4,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : 0,
  "active_shards" : 0,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0
}

```

Lets get some more details on the cluster:

```bash
curl "http://$MASTER_IP:9200/_cluster/state?pretty=true"
{
  "cluster_name" : "elasticsearch",
  "version" : 5,
  "master_node" : "yQHnYFFjTtSO8cVHv9ychg",
  "blocks" : { },
  "nodes" : {
    "x7l7vBN9QnKFW4HZzGKMnA" : {
      "name" : "es-d9b96354c62f",
      "transport_address" : "inet[/192.168.128.17:9300]",
      "attributes" : {
        "master" : "true"
      }
    },
    "V8C_Mi8SRvuuNZj0mBvjFg" : {
      "name" : "es-11796a8a77cb",
      "transport_address" : "inet[/192.168.128.16:9300]",
      "attributes" : {
        "master" : "true"
      }
    },
    "k8Fqw3jXQBCK7ArUWRoYgQ" : {
      "name" : "es-e36436b26d05",
      "transport_address" : "inet[/192.168.128.15:9300]",
      "attributes" : {
        "master" : "true"
      }
    },
    "yQHnYFFjTtSO8cVHv9ychg" : {
      "name" : "es-17e3539d1c47",
      "transport_address" : "inet[/192.168.128.14:9300]",
      "attributes" : {
        "data" : "false",
        "master" : "true"
      }
    }
  },
  "metadata" : {
    "templates" : { },
    "indices" : { }
  },
  "routing_table" : {
    "indices" : { }
  },
  "routing_nodes" : {
    "unassigned" : [ ],
    "nodes" : {
      "x7l7vBN9QnKFW4HZzGKMnA" : [ ],
      "k8Fqw3jXQBCK7ArUWRoYgQ" : [ ],
      "V8C_Mi8SRvuuNZj0mBvjFg" : [ ]
    }
  },
  "allocations" : [ ]
}

```
