FROM alpine
# MAINTAINER squad:Energon

LABEL name="Elasticsearch Image For Cluster" \
    image-from="elasticsearch:7.10.1"

# Set environment variables defaults
ENV ES_VERSION 7.10.1
ENV JAVA_ALPINE_VERSION 11
ENV ES_DISCOVERY_SERVICE es-svc-master-7
ENV ES_CLIENT_SERVICE elasticsearch7
ENV ES_JAVA_OPTS="-Xms512m -Xmx512m" \
    CLUSTER_NAME=es-cluster \
    NODE_MASTER=true \
    NODE_DATA=true \
    NODE_INGEST=true \
    HTTP_ENABLE=true \
    NETWORK_HOST=_site_ \
    MEMORY_LOCK=false \
    HTTP_CORS_ENABLE=true \
    HTTP_CORS_ALLOW_ORIGIN=\"*\" \
    NUMBER_OF_MASTERS=1 \
    MAX_LOCAL_STORAGE_NODES=1 \
    SHARD_ALLOCATION_AWARENESS="" \
    SHARD_ALLOCATION_AWARENESS_ATTR="" \
    # For search guard default password
    KEY_PASS="password"
ENV PATH /opt/elasticsearch-$ES_VERSION/bin:/usr/lib/jvm/java-11-openjdk/bin:/usr/lib/jvm/java-11-openjdk/jre/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk

WORKDIR /tmp

RUN apk update \
  && apk upgrade \
  && apk add --no-cache apr \
  && apk add --no-cache bash openssl curl \
  && apk add --no-cache openjdk11 \
  && rm -rf /var/cache/apk/* \
  && curl -SLOk -s "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ES_VERSION-linux-x86_64.tar.gz" \
  && curl -SLOk -s "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ES_VERSION-linux-x86_64.tar.gz/sha512" \
  && addgroup -S -g 1000 esgroup \
  && adduser -S -D -u 1000 esuser -G esgroup \
  && mkdir -p /opt \
  && tar -zxvf elasticsearch-$ES_VERSION-linux-x86_64.tar.gz -C /opt \
  && rm elasticsearch-$ES_VERSION-linux-x86_64.tar.gz sha512 \
  && chown -R esuser:esgroup /opt/elasticsearch-$ES_VERSION  

RUN rm -r /opt/elasticsearch-$ES_VERSION/modules/x-pack-security \
  && rm -r /opt/elasticsearch-$ES_VERSION/modules/x-pack-ml \
  && rm -r /opt/elasticsearch-$ES_VERSION/jdk

WORKDIR /opt/elasticsearch-$ES_VERSION

USER root

# Add gosu to switch user
RUN cd /usr/local/bin/ \
  && curl -SLOk -s "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" \
  && curl -SLOk -s "https://github.com/tianon/gosu/releases/download/1.14/SHA256SUMS" \
  && rm SHA256SUMS \
  && mv gosu-* gosu \
  && chmod +x /usr/local/bin/gosu \
  && chmod -R 755 /opt/elasticsearch-$ES_VERSION/bin/

# Install plugins

RUN gosu esuser ./bin/elasticsearch-plugin install -b https://maven.search-guard.com:443//search-guard-suite-release/com/floragunn/search-guard-suite-plugin/7.10.1-48.0.0/search-guard-suite-plugin-7.10.1-48.0.0.zip \ 
  && gosu esuser ./bin/elasticsearch-plugin install mapper-murmur3

# Copy configuration
COPY config ./config
COPY sgconfig ./plugins/search-guard-7/sgconfig
COPY probe ./probe
COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY mappings ./config/mappings
COPY REINDEX ./probe/REINDEX
# Copy run script
COPY run_es.sh ./

#RUN curl -SLk -o /opt/elasticsearch-$ES_VERSION/plugins/search-guard-7/netty-tcnative-openssl-1.1.0j-static-2.0.15.Final-non-fedora-linux-x86_64.jar "https://maven.search-guard.com:443//netty-tcnative/netty-tcnative-openssl-1.1.0j-static-2.0.15.Final-non-fedora-linux-x86_64.jar" \

RUN curl -SLk -o /opt/elasticsearch-$ES_VERSION/plugins/search-guard-7/netty-tcnative-2.0.33.Final-linux-x86_64.jar "https://search.maven.org/remotecontent?filepath=io/netty/netty-tcnative/2.0.33.Final/netty-tcnative-2.0.33.Final-linux-x86_64.jar" \
  && mkdir /data /backup \
  && chown -R esuser:esgroup /data /backup ./config ./probe ./plugins/search-guard-7 run_es.sh \
  && chmod -R +x ./probe /usr/bin/entrypoint.sh

#Remove netcat softlink from Alpine image
RUN rm /usr/bin/nc

#Patch log4j jar due to CVE-2021-44228
RUN cd /opt/elasticsearch-7.10.1/lib \
  && curl https://dlcdn.apache.org/logging/log4j/2.19.0/apache-log4j-2.19.0-bin.zip --output l4j.zip \
  && unzip  l4j.zip \
  && cp apache-log4j-2.19.0-bin/log4j-core-2.19.0.jar . \
  && chown esuser:esgroup log4j-core-2.19.0.jar \
  && rm -f log4j-core-2.11.1.jar \
  && cp apache-log4j-2.19.0-bin/log4j-api-2.19.0.jar . \
  && chown esuser:esgroup log4j-api-2.19.0.jar \
  && rm -f log4j-api-2.11.1.jar \
  && rm -f /opt/elasticsearch-7.10.1/modules/x-pack-core/log4j-1.2-api-2.11.1.jar \
  #log4j-slf4j-impl-2.19.0.jar
  && cp apache-log4j-2.19.0-bin/log4j-slf4j-impl-2.19.0.jar /opt/elasticsearch-7.10.1/plugins/search-guard-7/ \
  && rm -f /opt/elasticsearch-7.10.1/plugins/search-guard-7/log4j-slf4j-impl-2.11.1.jar \
  && cp apache-log4j-2.19.0-bin/log4j-slf4j-impl-2.19.0.jar /opt/elasticsearch-7.10.1/modules/x-pack-identity-provider/ \
  && rm -f /opt/elasticsearch-7.10.1/modules/x-pack-identity-provider/log4j-slf4j-impl-2.11.1.jar \
  #cleanup our zip and dir
  && rm -rf apache-log4j-2.19.0-bin \
  && rm -f l4j.zip


# Volume for Elasticsearch data
VOLUME ["/data", "/backup", "/opt/elasticsearch-$ES_VERSION/config/certs"]

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

# Expose ports.
#   - 9200: HTTP
#   - 9300: transport
EXPOSE 9200
EXPOSE 9300

