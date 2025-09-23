#!/bin/bash
# Check whether current node is available inside a cluster

# this path of util script sendRequest.sh.
# pls change it to the path in your env. e.g:
#   /opt/elasticsearch-7.10.1/probe/sendRequest.sh
sendRequest="/opt/elasticsearch-${ES_VERSION}/probe/sendRequest.sh"

set -f
response_text=$(${sendRequest} --to-master GET /_cat/nodes?h=master)

echo "${response_text}"
set +f
# if return text contains asterisk, then master is OK.
if [[ ${response_text} == *"*"* ]]; then
  exit 0
else
  exit 1
fi
