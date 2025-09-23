#!/bin/bash

# Set a random node name if not set.
if [ -z "${NODE_NAME}" ]; then
  NODE_NAME=`hostname -s`
fi
export NODE_NAME=${NODE_NAME}

# Prevent "Text file busy" errors
sync

if [ ! -z "${ES_PLUGINS_INSTALL}" ]; then
  OLDIFS=$IFS
  IFS=','
  for plugin in ${ES_PLUGINS_INSTALL}; do
    if ! /opt/bin/elasticsearch-plugin list | grep -qs ${plugin}; then
      yes | `pwd`/bin/elasticsearch-plugin install --batch ${plugin}
    fi
  done
  IFS=$OLDIFS
fi

if [ ! -z "${SHARD_ALLOCATION_AWARENESS_ATTR}" ]; then
  if [ "$NODE_DATA" == "true" ]; then
    ES_SHARD_ATTR=`cat ${SHARD_ALLOCATION_AWARENESS_ATTR}`
    NODE_NAME="${ES_SHARD_ATTR}-${NODE_NAME}"
    echo "node.attr.${SHARD_ALLOCATION_AWARENESS}: ${ES_SHARD_ATTR}" >> /opt/config/elasticsearch.yml
  fi
  if [ "$NODE_MASTER" == "true" ]; then
    echo "cluster.routing.allocation.awareness.attributes: ${SHARD_ALLOCATION_AWARENESS}" >> /opt/config/elasticsearch.yml
  fi
fi

if [ "$NODE_DATA" == "true" ]; then
    find /data/data/nodes/0/ -name .es_temp_file -print | xargs -n 1 rm
fi

# search-guard doesn't support env var substitution, so generate yml from template.
esconfig=`cat ./config/elasticsearch.template.yml`
printf "cat << EOF\n$esconfig\nEOF" | bash > ./config/elasticsearch.yml

#Configure to true for data migration from elasticsearch5 to elasticsearch7
if [ "$ELASTICSEARCH5_MIGRATE" == "true" ]; then
if [ "$NODE_INGEST" == "true" ]; then
esconfig=`cat ./config/elasticsearch.reindex.yml`
printf "cat << EOF\n$esconfig\nEOF" | bash >> ./config/elasticsearch.yml
fi
fi

#Spin-up ES7 Nodes
exec /opt/elasticsearch-$ES_VERSION/bin/elasticsearch
