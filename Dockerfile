FROM debian:jessie

RUN apt-get update && \
    apt-get install -y \
    openjdk-7-jre \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64

# If we wanted the development version we could pull that instead but we want to
# run a production environment here
RUN export ES_PKG=elasticsearch-2.1.0.deb && \
    curl -LO https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/2.1.0/${ES_PKG} && \
    dpkg -i ${ES_PKG} && \
    rm ${ES_PKG} && \
    rm /etc/elasticsearch/elasticsearch.yml

# get Containerbuddy release
RUN export CB=containerbuddy-0.0.2-alpha &&\
    mkdir -p /opt/containerbuddy && \
    curl -Lo /tmp/${CB}.tar.gz \
    https://github.com/joyent/containerbuddy/releases/download/0.0.2-alpha/${CB}.tar.gz && \
	tar -xf /tmp/${CB}.tar.gz && \
    mv /build/containerbuddy /opt/containerbuddy/

# Take ownership over required directories
RUN mkdir -p /var/lib/elasticsearch/data && \
    chown -R elasticsearch:elasticsearch /var/lib/elasticsearch/data && \
    chown -R root:elasticsearch /etc/elasticsearch && \
    chmod g+w /etc/elasticsearch

USER elasticsearch

# Add our configuration files and scripts
COPY /etc/containerbuddy /etc/
COPY /etc/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
COPY /bin/onStart.sh /opt/containerbuddy/onStart.sh

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
