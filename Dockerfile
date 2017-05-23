FROM docker.elastic.co/elasticsearch/elasticsearch-alpine-base:latest

# LICENSE - Apache License 2.0
# https://github.com/elastic/elasticsearch-alpine-base/blob/master/LICENSE

ENV ELASTIC_VERSION=5.3.0 \
    PATH=/usr/share/elasticsearch/bin:$PATH \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
    CONSUL_VERSION=0.7.5 \
    CONSUL_CLI_VER=0.3.1 \
    CONTAINERPILOT_VER=2.7.2 \
    CONTAINERPILOT=file:///etc/containerpilot.json

WORKDIR /usr/share/elasticsearch

# Required dependencies
RUN apk update && \
    apk add jq curl unzip tar && \
    rm -rf /var/cache/apk/*

# Download/extract defined ES version. busybox tar can't strip leading dir.
RUN export ELASTIC_CHECKSUM=9273fdecb2251755887f1234d6cfcc91e44a384d && \
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VERSION}.tar.gz && \
    test $ELASTIC_CHECKSUM == $(sha1sum elasticsearch-${ELASTIC_VERSION}.tar.gz | awk '{print $1}') && \
    tar zxf elasticsearch-${ELASTIC_VERSION}.tar.gz && \
    chown -R elasticsearch:elasticsearch elasticsearch-${ELASTIC_VERSION} && \
    mv elasticsearch-${ELASTIC_VERSION}/* . && \
    rmdir elasticsearch-${ELASTIC_VERSION} && \
    rm elasticsearch-${ELASTIC_VERSION}.tar.gz

RUN set -ex && for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
        chown -R elasticsearch:elasticsearch "$esdirs"; \
    done

# Add consul agent
RUN export CONSUL_CHECKSUM=40ce7175535551882ecdff21fdd276cef6eaab96be8a8260e0599fadb6f1f5b8 \
    && curl --retry 7 --fail -vo /tmp/consul.zip "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && echo "${CONSUL_CHECKSUM}  /tmp/consul.zip" | sha256sum -c \
    && unzip /tmp/consul -d /usr/local/bin \
    && rm /tmp/consul.zip

# Consul client
RUN export CONSUL_CLIENT_CHECKSUM=037150d3d689a0babf4ba64c898b4497546e2fffeb16354e25cef19867e763f1 \
    && curl -Lso /tmp/consul-cli.tgz "https://github.com/CiscoCloud/consul-cli/releases/download/v${CONSUL_CLI_VER}/consul-cli_${CONSUL_CLI_VER}_linux_amd64.tar.gz" \
    && echo "${CONSUL_CLIENT_CHECKSUM}  /tmp/consul-cli.tgz" | sha256sum -c \
    && tar zxf /tmp/consul-cli.tgz -C /usr/local/bin --strip-components 1 \
    && rm /tmp/consul-cli.tgz

# Add ContainerPilot and set its configuration file path
RUN export CONTAINERPILOT_CHECKSUM=e886899467ced6d7c76027d58c7f7554c2fb2bcc \
    && curl -Lso /tmp/containerpilot.tar.gz \
        "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VER}/containerpilot-${CONTAINERPILOT_VER}.tar.gz" \
    && echo "${CONTAINERPILOT_CHECKSUM}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz

USER elasticsearch
COPY /etc/containerpilot.json /etc/
COPY /etc/elasticsearch.yml config/
COPY /etc/log4j2.properties config/
COPY /bin/es-docker bin/es-docker
COPY /bin/* /usr/local/bin/

USER root
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml config/log4j2.properties bin/es-docker && \
    chmod 0750 bin/es-docker && \
    mkdir -p /opt/consul/config && \
    mkdir -p /opt/consul/data && \
    chmod 770 /opt/consul/data && \
    chown -R elasticsearch:elasticsearch /opt/consul && \
    mkdir -p /etc/containerpilot && \
    chmod -R g+w /etc/containerpilot && \
    chmod +x /usr/local/bin/elastic-server.sh && \
    chown -R elasticsearch:elasticsearch /etc/containerpilot

USER elasticsearch

# Expose the data directory as a volume in case we want to mount these
# as a --volumes-from target; it's important that this VOLUME comes
# after the creation of the directory so that we preserve ownership.
VOLUME ["/usr/share/elasticsearch/data"]

# Start with containerpilot then to our wrapper
CMD ["containerpilot", "/usr/local/bin/elastic-server.sh"]


EXPOSE 9200 9300
