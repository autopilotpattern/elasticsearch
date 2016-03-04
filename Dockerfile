FROM alpine:3.3

RUN apk --update add \
    openjdk7-jre \
    curl \
    jq

ENV JAVA_HOME /usr/lib/jvm/java-1.7-openjdk

# If we wanted the development version we could pull that instead but we want to
# run a production environment here. Ideally we'd be using an official binary
# package that includes all the setup but Elastico doesn't ship an apk
RUN addgroup -S elasticsearch \
    && adduser -SG elasticsearch elasticsearch \
    && export ES_PKG=elasticsearch-2.2.0.tar.gz \
    && export ES_SHA1=4bd3ef681e70faefe3a66c6eb3419b5d4a0e2714 \
    && curl -Ls --fail -o /tmp/${ES_PKG} https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/2.2.0/${ES_PKG} \
    && echo "${ES_SHA1}  /tmp/${ES_PKG}" | sha1sum -c \
    && mkdir /opt \
    && tar zxf /tmp/${ES_PKG} -C /opt \
    && mv /opt/elasticsearch-2.2.0 /opt/elasticsearch \
    && rm /tmp/${ES_PKG}

# get Containerbuddy release
ENV CONTAINERBUDDY_VERSION 1.1.0
RUN export CB_SHA1=5cb5212707b5a7ffe41ee916add83a554d1dddfa \
    && curl -Lso /tmp/containerbuddy.tar.gz \
         "https://github.com/joyent/containerbuddy/releases/download/${CONTAINERBUDDY_VERSION}/containerbuddy-${CONTAINERBUDDY_VERSION}.tar.gz" \
    && echo "${CB_SHA1}  /tmp/containerbuddy.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerbuddy.tar.gz -C /bin \
    && rm /tmp/containerbuddy.tar.gz

# Create and take ownership over required directories
RUN mkdir -p /var/lib/elasticsearch/data \
    && mkdir -p /etc/elasticsearch \
    && mkdir -p /var/log/elasticsearch \
    && chown -R elasticsearch:elasticsearch /opt/elasticsearch \
    && chown -R elasticsearch:elasticsearch /var/lib/elasticsearch/data \
    && chown -R root:elasticsearch /etc/elasticsearch \
    && chown -R root:elasticsearch /var/log/elasticsearch \
    && chmod g+w /etc/elasticsearch

USER elasticsearch

# Add our configuration files and scripts
COPY /etc/containerbuddy.json /etc
COPY /etc/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
COPY /bin/onStart.sh /bin

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
