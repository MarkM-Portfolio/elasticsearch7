#!/bin/bash
# for additional usage, pls refer to official site:
# https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-snapshots.html
# https://www.elastic.co/guide/en/elasticsearch/guide/current/_restoring_from_a_snapshot.html
# PS: with ./sendRequest.sh, you can interact with es like what official site suggested.

set -o errexit
set -o pipefail
set -o nounset

# this path of util script sendRequest.sh.
# pls change it to the path in your env. e.g:
#   /opt/elasticsearch-7.10.1/probe/sendRequest.sh
sendRequest="/opt/elasticsearch-${ES_VERSION}/probe/sendRequest.sh"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "usage:  sendRequest param_REPO_name param_snapshot_name"
  exit 107
fi

# Name of our snapshot repository
REPO=${1}

# Name of the snapshot used to restore
SNAPSHOT=${2}

echo "----------------We need to close the index first"
${sendRequest} POST /_all/_close
# to only close given index, which means only given index can be restore.
# because index needed to be closed before restoration.
#./sendRequest.sh POST /${INDEX}/_close

echo "----------------to restore a snapshot ${SNAPSHOT} in repo ${REPO}"
${sendRequest} POST /_snapshot/${REPO}/${SNAPSHOT}/_restore?wait_for_completion=true


# to only restore given index(here in this example ${INDEX})
# ${sendRequest} POST /_snapshot/${REPO}/${SNAPSHOT}/_restore?wait_for_completion=true \
# -d '{"indices": "${INDEX}"}'


# the restored indices will be opened automatically.


# echo "----------------to check the status of all indices"
# ${sendRequest} GET /_cat/indices?v

exit 0
