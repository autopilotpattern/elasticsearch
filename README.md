Autopilot Pattern Elasticsearch
==========

[Elasticsearch](https://www.elastic.co/products) designed for automated operation using the [Autopilot Pattern](http://autopilotpattern.io/).

[![DockerPulls](https://img.shields.io/docker/pulls/autopilotpattern/elasticsearch.svg)](https://registry.hub.docker.com/u/autopilotpattern/elasticsearch/)
[![DockerStars](https://img.shields.io/docker/stars/autopilotpattern/elasticsearch.svg)](https://registry.hub.docker.com/u/autopilotpattern/elasticsearch/)
[![ImageLayers](https://badge.imagelayers.io/autopilotpattern/elasticsearch:latest.svg)](https://imagelayers.io/?images=autopilotpattern/elasticsearch:latest)
[![Join the chat at https://gitter.im/autopilotpattern/general](https://badges.gitter.im/autopilotpattern/general.svg)](https://gitter.im/autopilotpattern/general)

### Discovery with ContainerPilot

Cloud deployments can't take advantage of multicast over the software-defined networks available from AWS, GCE, or Joyent's Triton. Although a separate plugin could be developed to run discovery, in this case we're going to take advantage of a fairly typical production topology for Elasticsearch -- master-only nodes.

When a data node starts, it will use [ContainerPilot](https://github.com/joyent/containerpilot) to query Consul and find a master node to bootstrap unicast zen discovery. We write this to the node configuration file on each start, so if the bootstrap node dies we can still safely reboot data nodes and join them to whatever master is available.

### Usage

1. [Get a Joyent account](https://my.joyent.com/landing/signup/) and [add your SSH key](https://docs.joyent.com/public-cloud/getting-started).
1. Install the [Docker Toolbox](https://docs.docker.com/installation/mac/) (including `docker` and `docker-compose`) on your laptop or other environment, as well as the [Joyent CloudAPI CLI tools](https://apidocs.joyent.com/cloudapi/#getting-started) (including the `smartdc` and `json` tools).

Launch a cluster with a single master-only node, a single data-only node, and a master/data node.

```bash
$ docker-compose -p es up -d
Pulling elasticsearch_master (autopilotpattern/elasticsearch:latest)...
latest: Pulling from autopilotpattern/elasticsearch
...
Status: Downloaded newer image for autopilotpattern/elasticsearch:latest
Creating es_consul_1...
Creating es_elasticsearch_master_1...
Creating es_elasticsearch_1...
Creating es_data_1...
```

Scale up that cluster to 3 master/data nodes.

```bash
$ docker-compose -p es scale elasticsearch=3
Creating and starting 2... done
Creating and starting 3... done

$ docker ps --format 'table {{ .ID }}\t{{ .Image }}\t{{ .Names }}'
8f675e1de88d        autopilotpattern/elasticsearch   es_elasticsearch_2
34f754d16a45        autopilotpattern/elasticsearch   es_elasticsearch_3
475f1e748f93        autopilotpattern/elasticsearch   es_elasticsearch_data_1
730ef555af95        autopilotpattern/elasticsearch   es_elasticsearch_master_1
dad25bc6659d        autopilotpattern/elasticsearch   es_elasticsearch_1
f806ec8d7da3        progrium/consul                  es_consul_1

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
$ curl "http://${MASTER_IP}:9200/_cluster/state?pretty=true"
{
  "cluster_name" : "elasticsearch",
  "version" : 6,
  "state_uuid" : "UTVIQa_sTJmOkzUghri3Kg",
  "master_node" : "KnRTARjyQ2-_OML81iiO8A",
  "blocks" : { },
  "nodes" : {
    "KnRTARjyQ2-_OML81iiO8A" : {
      "name" : "es-730ef555af95",
      "transport_address" : "192.168.128.137:9300",
      "attributes" : {
        "data" : "false",
        "master" : "true"
      }
    },
    "T4AA6uvZRe-kCaE-nDM9ww" : {
      "name" : "es-dad25bc6659d",
      "transport_address" : "192.168.128.136:9300",
      "attributes" : {
        "master" : "true"
      }
    },
    "a-4ER37vQqCDak7K-2DH8A" : {
      "name" : "es-475f1e748f93",
      "transport_address" : "192.168.128.138:9300",
      "attributes" : {
        "master" : "false"
      }
    },
    "a06pnuRSQIG9kvXTDEiLhA" : {
      "name" : "es-8f675e1de88d",
      "transport_address" : "192.168.128.140:9300",
      "attributes" : {
        "master" : "true"
      }
    },
    "TgDqSKQTTnigBdUF6_Fdkg" : {
      "name" : "es-34f754d16a45",
      "transport_address" : "192.168.128.139:9300",
      "attributes" : {
        "master" : "true"
      }
    }
  },
  "metadata" : {
    "cluster_uuid" : "uTvKs32PStW0Q4swo2v-dQ",
    "templates" : { },
    "indices" : { }
  },
  "routing_table" : {
    "indices" : { }
  },
  "routing_nodes" : {
    "unassigned" : [ ],
    "nodes" : {
      "TgDqSKQTTnigBdUF6_Fdkg" : [ ],
      "a06pnuRSQIG9kvXTDEiLhA" : [ ],
      "T4AA6uvZRe-kCaE-nDM9ww" : [ ],
      "a-4ER37vQqCDak7K-2DH8A" : [ ]
    }
  }
}

```
