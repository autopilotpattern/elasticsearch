FROM debian:jessie

RUN apt-get update && \
    apt-get install -y \
    openjdk-7-jre \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64

# If we wanted the develop version we could pull that instead but we want to
# run a production environment here
RUN export ES_PKG=elasticsearch-1.7.1.deb && \
    curl -LO https://download.elastic.co/elasticsearch/elasticsearch/${ES_PKG} && \
    dpkg -i ${ES_PKG} && \
    rm ${ES_PKG} && \
    rm /etc/elasticsearch/elasticsearch.yml

# Add our configuration files
ADD /etc/elasticsearch /etc/elasticsearch/

# Expose the data directory as a volume in case we want to mount these
# as a --volumes-from target
VOLUME /var/lib/elasticsearch/data

EXPOSE 9200
EXPOSE 9300
