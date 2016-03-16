FROM debian:jessie

RUN apt-get update && \
    apt-get install -y \
    openjdk-7-jre \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64

# If we wanted the development version we could pull that instead but we want to
# run a production environment here.
RUN export ES_PKG=elasticsearch-2.2.0.deb && \
    curl -LO https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/2.2.0/${ES_PKG} && \
    dpkg -i ${ES_PKG} && \
    rm ${ES_PKG} && \
    rm /etc/elasticsearch/elasticsearch.yml

# get Containerbuddy release
ENV CONTAINERBUDDY_VERSION 1.2.1
RUN export CB_SHA1=aca04b3c6d6ed66294241211237012a23f8b4f20 \
    && curl -Lso /tmp/containerbuddy.tar.gz \
        "https://github.com/joyent/containerbuddy/releases/download/${CONTAINERBUDDY_VERSION}/containerbuddy-${CONTAINERBUDDY_VERSION}.tar.gz" \
    && echo "${CB_SHA1}  /tmp/containerbuddy.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerbuddy.tar.gz -C /bin \
    && rm /tmp/containerbuddy.tar.gz

# Create and take ownership over required directories
RUN mkdir -p /var/lib/elasticsearch/data && \
    chown -R elasticsearch:elasticsearch /var/lib/elasticsearch/data && \
    chown -R root:elasticsearch /etc/elasticsearch && \
    chmod g+w /etc/elasticsearch

USER elasticsearch

# Add our configuration files and scripts
COPY /etc/containerbuddy.json /etc
COPY /etc/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
COPY /bin/manage.sh /bin

# Expose the data directory as a volume in case we want to mount these
# as a --volumes-from target; it's important that this VOLUME comes
# after the creation of the directory so that we preserve ownership.
VOLUME /var/lib/elasticsearch/data

# We don't need to expose these ports in order for other containers on Triton
# to reach this container in the default networking environment, but if we
# leave this here then we get the ports as well-known environment variables
# for purposes of linking.
EXPOSE 9200
EXPOSE 9300
